import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig, TURN_TIMEOUT_SEC } from "../config";
import { applyWalletDelta, sendPokeNotification } from "../utils"; // Import needed utils
import { startDMInternal, sendMessageInternal, getDmId } from "../controllers/chat"; // Import chat helpers
import { getBotDecision } from "../bot";
import { executeBotAction, submitMoveInternal } from "../controllers/game";
import { applyMoveAndReturnState, getNextPlayerUid } from "../logic";

// ---------------------------------------------
// botTurn (Trigger)
// ---------------------------------------------
export const botTurn = functions.database
    .ref("games/{gameId}")
    .onUpdate(async (change, context) => {
        const gameId = context.params.gameId;
        const game = change.after.val();

        if (!game || game.turn !== "BOT_PLAYER" || game.state !== "active") {
            return null;
        }

        // Wait 5 seconds before bot moves (increased reliability/delay)
        await new Promise((r) => setTimeout(r, 5000));

        // Re-fetch game to ensure state hasn't changed during wait
        const freshSnap = await db.ref(`games/${gameId}`).get();
        if (!freshSnap.exists()) return null;
        const freshGame = freshSnap.val();

        if (freshGame.turn !== "BOT_PLAYER" || freshGame.state !== "active") return null;

        console.log(`🤖 BOT_TURN: Triggered for ${gameId}, Phase: ${freshGame.turnPhase}`);
        const decision = getBotDecision(freshGame, "BOT_PLAYER");
        await executeBotAction(gameId, "BOT_PLAYER", decision, freshGame);

        return null;
    });

// ---------------------------------------------
// autoPlayTurns (Trigger)
// ---------------------------------------------
export const autoPlayTurns = functions.database
    .ref("games/{gameId}/lastMoveTime")
    .onWrite(async (change, context) => {
        const gameId = context.params.gameId;
        const newTime = change.after.val();

        if (!newTime) return null;

        // Wait for turn timeout
        const gameRef = db.ref(`games/${gameId}`);
        const gameSnap = await gameRef.get();
        if (!gameSnap.exists()) return null;
        const game = gameSnap.val();

        if (game.state !== "active") return null;
        if (game.lastMoveTime !== newTime) return null; // Stale event

        const now = Date.now();
        const deadline = game.turnDeadlineTs || 0;
        const delay = Math.max(0, deadline - now);

        // Wait until deadline
        if (delay > 0) {
            await new Promise((r) => setTimeout(r, delay));
        }

        // Re-check state after wait
        const freshSnap = await gameRef.get();
        if (!freshSnap.exists()) return null;
        const freshGame = freshSnap.val();

        if (freshGame.state !== "active") return null;
        if (freshGame.lastMoveTime !== newTime) return null; // Someone moved

        const currentPlayer = freshGame.turn;
        const phase = freshGame.turnPhase;

        console.log(`⏱️ AUTO_PLAY: Timer expired for player ${currentPlayer} in phase ${phase}`);

        // Safeguard: If player is LEFT, skip immediately (do not roll/move)
        const pData = freshGame.players[currentPlayer];
        if (pData && (pData.status === 'left' || pData.status === 'kicked')) {
            console.log(`⚠️ AUTO_PLAY: Player ${currentPlayer} is ${pData.status}. Skipping turn.`);
            await executeBotAction(gameId, currentPlayer, { type: 'skip' }, freshGame);
            return null;
        }

        const decision = getBotDecision(freshGame, currentPlayer);

        await executeBotAction(gameId, currentPlayer, decision, freshGame);

        return null;
    });

// ---------------------------------------------
// onDiceRolled (Trigger)
// ---------------------------------------------
export const onDiceRolled = functions.database
    .ref("games/{gameId}/turnPhase")
    .onUpdate(async (change, context) => {
        const phase = change.after.val();
        if (phase !== "rollingAnim") return null;

        const gameId = context.params.gameId;

        // Wait for animation (~600ms)
        await new Promise((r) => setTimeout(r, 600));

        const gameRef = db.ref(`games/${gameId}`);
        const snap = await gameRef.get();
        if (!snap.exists()) return null;
        const game = snap.val();

        if (game.turnPhase !== "rollingAnim") return null; // Phase changed?

        const uid = game.turn;
        const roll = game.diceValue;

        // Check for valid moves
        let hasValidMove = false;
        let validMoveCount = 0;
        let singleValidMoveIndex = -1;

        for (let i = 0; i < 4; i++) {
            try {
                applyMoveAndReturnState(game, uid, i, roll);
                hasValidMove = true;
                validMoveCount++;
                singleValidMoveIndex = i;
            } catch (e) {
                // invalid
            }
        }

        const now = Date.now();

        if (!hasValidMove) {
            // No moves, skip turn
            const nextTurnUid = getNextPlayerUid(game, uid);
            await gameRef.update({
                turn: nextTurnUid,
                turnPhase: "waitingRoll",
                consecutiveSixes: 0,
                turnDeadlineTs: now + TURN_TIMEOUT_SEC * 1000,
                turnStartedAt: now,
                lastMoveTime: now,
                updatedAt: now,
            });
            return null;
        }

        // Moves available
        await gameRef.update({
            turnPhase: "waitingMove",
            updatedAt: now,
            lastMoveTime: now, // Trigger autoPlayTurns if needed
        });

        // If single move, auto-execute?
        if (validMoveCount === 1) {
            // Add a small delay for user to see the dice result before move happens
            await new Promise((r) => setTimeout(r, 500));
            // Call submitMoveInternal from controller
            await submitMoveInternal(gameId, uid, singleValidMoveIndex);
        }

        return null;
    });

// ---------------------------------------------
// onGameCompleted (Trigger) - With 4P Fix
// ---------------------------------------------
export const onGameCompleted = functions.database
    .ref("games/{gameId}/state")
    .onWrite(async (change, context) => {
        const after = change.after.val();
        if (after !== "completed") return null;

        const gameId = context.params.gameId;
        const gameRef = change.after.ref.parent; // /games/{gameId}
        const gameSnap = await gameRef!.get();
        const game = gameSnap.val();

        const winnerUid = game.winnerUid;
        if (!winnerUid) return null;

        const tableId = game.tableId;
        const config = await getConfig();
        const stake = Number(game.stake || config.modes['2p'].stake);
        const rake = Number(game.rake || 0.0);

        // Get all players
        const playerUids = Object.keys(game.players || {});

        // --- 2P Logic ---
        if (playerUids.length === 2) {
            const prizePool = stake * playerUids.length; // 1000 * 2 = 2000
            const rakeAmount = Math.floor(prizePool * rake);
            const winnerPayout = prizePool - rakeAmount;

            await applyWalletDelta(winnerUid, +winnerPayout, "win_payout", {
                currency: 'gold',
                gameId,
                tableId,
                meta: { stake, rake, prizePool },
            });
            console.log(`💰 PAYOUT (2P): Winner ${winnerUid} got ${winnerPayout} gold in game ${gameId}`);

            // --- Activity Stream Injection (2P) ---
            // Log "Game Result" to the DM between P1 and P2
            if (playerUids.length === 2 && !playerUids.includes("BOT_PLAYER")) {
                const p1 = playerUids[0];
                const p2 = playerUids[1];
                const convId = getDmId(p1, p2);

                try {
                    await startDMInternal(p1, p2);

                    await sendMessageInternal(
                        winnerUid, // Sender
                        convId,
                        null, // No Text
                        'game_result',
                        {
                            winner: winnerUid === p1 ? 'Player 1' : 'Player 2', // TODO: Fetch Names?
                            score: 'Winner', // Simple for now
                            mode: '2 Player'
                        },
                        {
                            gameId,
                            tableId
                        }
                    );
                    console.log(`📜 ACTIVITY: Logged Game Result to ${convId}`);
                } catch (e) {
                    console.error("Failed to log activity", e);
                }
            }

        }
        // --- 4P Team Logic ---
        else if (playerUids.length === 4) {
            const winnerData = game.players[winnerUid];
            const winningTeamId = winnerData?.team; // 0 or 1

            if (winningTeamId === undefined || winningTeamId === null) {
                console.error(`💰 PAYOUT (4P): Winner ${winnerUid} has no team ID. Aborting payout.`);
                return null;
            }

            // Find all winning team members
            const winners: string[] = [];
            for (const [uid, data] of Object.entries(game.players) as [string, any][]) {
                if (data.team === winningTeamId) {
                    winners.push(uid);
                }
            }

            // Total Pot = 4 * Stake
            const prizePool = stake * 4;
            const rakeAmount = Math.floor(prizePool * rake);
            const netPool = prizePool - rakeAmount;

            const payoutPerPlayer = Math.floor(netPool / winners.length);

            for (const wUid of winners) {
                await applyWalletDelta(wUid, +payoutPerPlayer, "win_payout", {
                    currency: 'gold',
                    gameId,
                    tableId,
                    meta: { stake, rake, prizePool, teamId: winningTeamId },
                });
                console.log(`💰 PAYOUT (4P): Teammate ${wUid} got ${payoutPerPlayer} gold.`);
            }
        }

        // Reset Status for ALL players
        const updates: any = {};
        for (const uid of playerUids) {
            if (uid !== "BOT_PLAYER") {
                updates[`userGameStatus/${uid}`] = {
                    status: "idle",
                    gameId: null,
                    tableId: null,
                    ts: Date.now(),
                };
                // Clear legacy fields
                updates[`users/${uid}/currentGameId`] = null;
                updates[`users/${uid}/currentTableId`] = null;
            }
        }
        // Update table status to completed
        if (tableId) {
            updates[`tables/${tableId}/status`] = "completed";
        }

        await db.ref().update(updates);
        return null;
    });

// ---------------------------------------------
// checkTimeouts (Scheduled) - Lifecycle
// ---------------------------------------------
export const checkTimeouts = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
        const snap = await db.ref("games").orderByChild("state").equalTo("active").get();
        const now = Date.now();
        const updates: any = {};
        const GAME_TIMEOUT_MIN = 15; // Hardcoded or imported? Imported is better.

        snap.forEach((child) => {
            const gameId = child.key!;
            const g = child.val();
            if (g.state !== "active") return;

            // Check for hard timeout (15 mins)
            if (now - g.updatedAt > GAME_TIMEOUT_MIN * 60 * 1000) {
                // Declare opponent as winner
                const loser = g.turn;
                const allPlayers = Object.keys(g.board || {});
                const winner = allPlayers.find((u: string) => u !== loser);
                if (!winner) return;

                updates[`games/${gameId}/state`] = "completed";
                updates[`games/${gameId}/winnerUid`] = winner;
                console.log(`Game ${gameId} timed out. Winner: ${winner}`);
            }
        });

        if (Object.keys(updates).length) {
            await db.ref().update(updates);
        }
        return null;
    });
