import * as functions from "firebase-functions";
import { db } from "../admin";
import { applyMoveAndReturnState, ApplyMoveResult, getNextPlayerUid } from "../logic";
import {
    TURN_TIMEOUT_SEC,
} from "../config";
import { BotAction } from "../bot";

// ---------------------------------------------
// rollDiceV2 (Callable)
// ---------------------------------------------
export const rollDiceV2 = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        // DEBUG: Return success with error field to verify if code is reached
        console.log("DEBUG: rollDiceV2 called without auth");
        return { error: "AUTH_MISSING_DEBUG", message: "Context.auth is undefined" };
    }
    const gameId = data.gameId as string;
    if (!gameId) {
        throw new functions.https.HttpsError("invalid-argument", "gameId required.");
    }

    return await rollDiceInternal(gameId, uid);
});

export async function rollDiceInternal(gameId: string, uid: string) {
    console.log(`DEBUG: rollDiceInternal called for gameId: ${gameId}, uid: ${uid}`);
    const gameRef = db.ref(`games/${gameId}`);
    const snap = await gameRef.get();

    if (!snap.exists()) {
        throw new functions.https.HttpsError("not-found", "Game not found.");
    }

    const game = snap.val();

    if (game.state !== "active") {
        throw new functions.https.HttpsError("failed-precondition", "Game is not active.");
    }
    if (game.turn !== uid) {
        throw new functions.https.HttpsError("failed-precondition", "Not your turn.");
    }
    // Allow rolling if waitingRoll
    if (game.turnPhase && game.turnPhase !== "waitingRoll" && game.turnPhase !== "rolling") { // Support legacy 'rolling' for migration
        throw new functions.https.HttpsError("failed-precondition", "You already rolled, please move a token.");
    }

    const board = game.board && game.board[uid];
    if (!Array.isArray(board) || board.length !== 4) {
        throw new functions.https.HttpsError("internal", "Invalid board for player.");
    }

    const allInBase = board.every((p: number) => p === -1);

    // Dice with special probability
    let roll: number;
    if (allInBase) {
        // 50% chance to be 6, otherwise 1–5 uniformly
        if (Math.random() < 0.5) {
            roll = 6;
        } else {
            const others = [1, 2, 3, 4, 5];
            roll = others[Math.floor(Math.random() * others.length)];
        }
    } else {
        roll = 1 + Math.floor(Math.random() * 6); // pure uniform 1–6
    }

    // Consecutive sixes
    let consecutiveSixes = game.consecutiveSixes || 0;
    if (roll === 6) {
        consecutiveSixes += 1;
    } else {
        consecutiveSixes = 0;
    }

    const now = Date.now();

    if (consecutiveSixes >= 3) {
        // Rule: on three 6s, turn is forfeited.
        const nextTurnUid = getNextPlayerUid(game, uid);

        await gameRef.update({
            diceValue: roll,
            consecutiveSixes: 0,
            turn: nextTurnUid,
            turnPhase: "waitingRoll",
            turnDeadlineTs: now + TURN_TIMEOUT_SEC * 1000,
            turnStartedAt: now,
            lastMoveTime: now,
            updatedAt: now,
        });

        return { roll, turnForfeited: true };
    }

    // Update state to rollingAnim
    await gameRef.update({
        diceValue: roll,
        consecutiveSixes,
        turnPhase: "rollingAnim",
        lastMoveTime: now,
        updatedAt: now,
    });

    return { roll, turnForfeited: false };
}

// ---------------------------------------------
// submitMove (Callable)
// ---------------------------------------------
export const submitMove = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }
    const gameId = data.gameId as string;
    const tokenIndex = Number(data.tokenIndex);

    return await submitMoveInternal(gameId, uid, tokenIndex);
});

export async function submitMoveInternal(gameId: string, uid: string, tokenIndex: number) {
    const gameRef = db.ref(`games/${gameId}`);
    const snap = await gameRef.get();
    if (!snap.exists()) {
        throw new functions.https.HttpsError("not-found", "Game not found.");
    }

    const game = snap.val();

    if (game.state !== "active") {
        throw new functions.https.HttpsError("failed-precondition", "Game not active.");
    }
    if (game.turn !== uid) {
        throw new functions.https.HttpsError("failed-precondition", "Not your turn.");
    }
    if (game.turnPhase !== "waitingMove") {
        throw new functions.https.HttpsError("failed-precondition", "You must roll first.");
    }

    const diceValue = Number(game.diceValue || 0);
    if (diceValue < 1 || diceValue > 6) {
        throw new functions.https.HttpsError("failed-precondition", "Invalid dice.");
    }

    let result: ApplyMoveResult;
    try {
        result = applyMoveAndReturnState(game, uid, tokenIndex, diceValue);
    } catch (e: any) {
        throw new functions.https.HttpsError("failed-precondition", e.message);
    }

    const updatedGame = {
        ...result.updatedGame,
    };

    // Decide next turn based on hasWon / extraTurn + 3x6 rule
    let nextTurnUid = game.turn;
    let turnPhase = "waitingRoll";
    let consecutiveSixes = game.consecutiveSixes || 0;

    if (result.hasWon) {
        // state & winner already set in updatedGame by logic.ts
        // Payout logic handled by onGameCompleted trigger
    } else {
        if (diceValue === 6 && result.extraTurn) {
            // player gets another roll
            nextTurnUid = uid;
            turnPhase = "waitingRoll";
        } else {
            nextTurnUid = getNextPlayerUid(game, uid);
            turnPhase = "waitingRoll";
            consecutiveSixes = 0;
        }
    }

    const now = Date.now();
    await gameRef.update({
        ...updatedGame,
        turn: nextTurnUid,
        turnPhase,
        consecutiveSixes,
        turnDeadlineTs: now + TURN_TIMEOUT_SEC * 1000,
        turnStartedAt: now,
        lastMoveTime: now,
        updatedAt: now,
    });

    return { success: true };
}

// ---------------------------------------------
// forfeitGame (Callable)
// ---------------------------------------------
export const forfeitGame = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }
    const gameId = data.gameId;
    if (!gameId) throw new functions.https.HttpsError("invalid-argument", "GameId required.");

    const gameRef = db.ref(`games/${gameId}`);
    const gameSnap = await gameRef.get();
    if (!gameSnap.exists()) throw new functions.https.HttpsError("not-found", "Game not found.");

    const game = gameSnap.val();
    if (game.state !== "active") throw new functions.https.HttpsError("failed-precondition", "Game not active.");

    // Validate user is player
    if (!game.players || !game.players[uid]) throw new functions.https.HttpsError("permission-denied", "Not a player.");

    const playerData = game.players[uid];
    const teamId = playerData.team; // 0 or 1 for 4P, undefined/null for 2P
    const isTeamMode = teamId !== undefined && teamId !== null;

    if (isTeamMode) {
        // --- 4P Team Logic ---
        console.log(`🏳️ FORFEIT (Team): ${uid} forfeiting in Team Mode (Team ${teamId})`);

        // Find Teammate
        const players = Object.entries(game.players); // [[uid, data], ...]
        const teammateEntry = players.find(([pUid, pData]: any) => pUid !== uid && pData.team === teamId);

        let teamLoss = false;

        if (teammateEntry) {
            const [teammateUid, teammateData] = teammateEntry as [string, any];
            // Check if teammate has ALREADY left
            if (teammateData.status === 'left') {
                console.log(`🏳️ FORFEIT (Team): Teammate ${teammateUid} already left. Team Loss.`);
                teamLoss = true;
            } else {
                console.log(`🏳️ FORFEIT (Team): Teammate ${teammateUid} is active. Marking ${uid} as LEFT.`);
                // Just mark as left
                const updates: any = {};
                updates[`players/${uid}/status`] = 'left';
                updates[`players/${uid}/leftAt`] = Date.now();

                // If it was my turn, skip me
                if (game.turn === uid) {
                    const nextUid = getNextPlayerUid(game, uid);
                    updates['turn'] = nextUid;
                    updates['turnPhase'] = 'waitingRoll';
                    updates['turnDeadlineTs'] = Date.now() + TURN_TIMEOUT_SEC * 1000;
                    updates['turnStartedAt'] = Date.now();
                    updates['updatedAt'] = Date.now();
                }

                await gameRef.update(updates);
                return { success: true, result: "left", message: "You have left the game." };
            }
        } else {
            // No teammate found? Should not happen in 4P unless corrupted. Treat as loss.
            console.warn(`🏳️ FORFEIT (Team): No teammate found for ${uid}. Defaulting to loss.`);
            teamLoss = true;
        }

        if (teamLoss) {
            // Find Opposing Team to declare winner
            // Any player from other team
            const opponentEntry = players.find(([pUid, pData]: any) => pData.team !== teamId);
            const winnerUid = opponentEntry ? opponentEntry[0] : null;

            if (winnerUid) {
                await gameRef.update({
                    state: "completed",
                    winnerUid: winnerUid, // Trigger will verify team and pay both
                    winnerReason: "opposing_team_forfeit",
                    loserUid: uid, // Initiator
                    updatedAt: Date.now()
                });
                return { success: true, result: "loss", message: "Your team forfeited." };
            }
        }

    } else {
        // --- 2P Logic (Existing) ---
        const players = Object.keys(game.players);
        const winnerUid = players.find(p => p !== uid);

        if (!winnerUid) {
            await gameRef.update({ state: "aborted" });
            return { success: true, result: "aborted" };
        }

        await gameRef.update({
            state: "completed",
            winnerUid: winnerUid,
            winnerReason: "opponent_forfeit",
            loserUid: uid,
            updatedAt: Date.now()
        });

        console.log(`🏳️ FORFEIT (2P): ${uid} forfeited. Winner: ${winnerUid}`);
        return { success: true, result: "loss" };
    }

    return { success: true };
});

// ---------------------------------------------
// Helper: Execute Bot Action
// ---------------------------------------------
export async function executeBotAction(gameId: string, uid: string, decision: BotAction, game: any) {
    console.log(`🤖 BOT_ACTION: ${uid} -> ${decision.type}`, decision);

    if (decision.type === "roll") {
        await rollDiceInternal(gameId, uid);
    } else if (decision.type === "move") {
        await submitMoveInternal(gameId, uid, decision.tokenIndex!);
    } else if (decision.type === "skip") {
        const nextUid = getNextPlayerUid(game, uid);
        await db.ref(`games/${gameId}`).update({
            turn: nextUid,
            turnPhase: "waitingRoll",
            consecutiveSixes: 0,
            turnDeadlineTs: Date.now() + TURN_TIMEOUT_SEC * 1000,
            turnStartedAt: Date.now(),
            lastMoveTime: Date.now(),
            updatedAt: Date.now(),
        });
    }
}
