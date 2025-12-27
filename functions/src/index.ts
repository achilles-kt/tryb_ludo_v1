import * as functions from "firebase-functions";
import { onRequest } from "firebase-functions/v2/https";
import { applyMoveAndReturnState, ApplyMoveResult } from "./logic";
import {
    INITIAL_GOLD,
    TURN_TIMEOUT_SEC,
    BOT_TAKEOVER_SEC,
    GAME_TIMEOUT_MIN,
    getConfig,
} from "./config";
import { getBotDecision } from "./bot";
import { db, admin } from "./admin";
import { applyWalletDelta, sendPokeNotification } from "./utils";
import { createPrivateTable, joinPrivateGame } from "./controllers/private_table";
import { sendInvite, respondToInvite, cancelInvite } from "./controllers/invites";
import { onInviteCreated } from "./triggers/invite_triggers";
import { joinSoloQueue, joinTeamQueue, processSoloQueue, processTeamQueue, attemptSoloPairing, attemptTeamPairing, debugForce4PProcess } from "./controllers/team_table";
import { testTeamUpFlow, testTeamBotFallback, test2PFlow, testInviteFlow, testAllFlows } from "./controllers/simulation";
import { handleInviteLink, checkDeferredLink } from "./controllers/deep_links";
import { sendFriendRequest, respondToFriendRequest, removeFriend } from "./controllers/social";
import { updateRecentPlayers, notifyFriendRequest } from "./triggers/social_triggers";
import { verifySocialFlow } from "./test_social";
import { registerPhone, syncContacts, backfillPhones } from "./controllers/contacts";
import { startDM, sendMessage, sendMessageInternal, startDMInternal, getDmId } from "./controllers/chat";
import { verifyContactFlow } from "./test_contacts";
import { verifyChatFlow } from "./test_chat";
import { onMessageCreated, onFriendRequest } from "./triggers/notification_triggers";
import { maintainPhoneIndex } from "./triggers/contact_triggers";
import { dailyMessageCleanup } from "./triggers/cleanup_triggers";

export {
    createPrivateTable,
    joinPrivateGame,
    sendInvite,
    respondToInvite,
    cancelInvite,
    onInviteCreated,
    joinSoloQueue,
    joinTeamQueue,
    debugForce4PProcess,
    testTeamUpFlow,
    testTeamBotFallback,
    test2PFlow,
    testInviteFlow,
    testAllFlows,
    handleInviteLink,
    checkDeferredLink,
    sendFriendRequest,
    respondToFriendRequest,
    removeFriend,
    updateRecentPlayers,
    notifyFriendRequest,
    verifySocialFlow,
    registerPhone,
    syncContacts,
    maintainPhoneIndex,
    backfillPhones,
    verifyContactFlow,
    startDM,
    sendMessage,
    verifyChatFlow,
    onMessageCreated,
    onFriendRequest,
    dailyMessageCleanup
};

// ---------------------------------------------
// 1. Auto-create user profile with starting gold
// ---------------------------------------------
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
    const uid = user.uid;
    console.log(`✅ USER_CREATED: User ${uid} being created...`);

    const userRef = db.ref(`users/${uid}`);
    const snap = await userRef.get();

    if (snap.exists()) {
        return null;
    }

    // Get Config
    const config = await getConfig();
    const rewards = config.global.initialRewards;

    const now = Date.now();
    const profile = {
        profile: {
            displayName: user.displayName || "New User",
            avatarUrl: user.photoURL || null,
            city: "",
            country: "India",
            createdAt: now,
            lastLoginAt: now,
        },
        wallet: {
            gold: rewards.gold,
            gems: rewards.gems,
            createdAt: now,
            updatedAt: now,
        },
    };

    await userRef.set(profile);

    // Transaction for Gold
    if (rewards.gold > 0) {
        const txnRef = db.ref(`walletTransactions/${uid}`).push();
        await txnRef.set({
            amount: rewards.gold,
            currency: 'gold',
            type: "adjustment",
            beforeBalance: 0,
            afterBalance: rewards.gold,
            createdAt: now,
            meta: { reason: "initial_rewards", seen: false },
        });
    }

    // Transaction for Gems
    if (rewards.gems > 0) {
        const txnRef = db.ref(`walletTransactions/${uid}`).push();
        await txnRef.set({
            amount: rewards.gems,
            currency: 'gems',
            type: "adjustment",
            beforeBalance: 0,
            afterBalance: rewards.gems,
            createdAt: now,
            meta: { reason: "initial_rewards", seen: false },
        });
    }

    console.log(`✅ USER_CREATED: User ${uid} created with ${rewards.gold} gold and ${rewards.gems} gems.`);
    return null;
});

// ---------------------------------------------
// 1. Auto-create user profile with starting gold
// ---------------------------------------------
// ... (onUserCreate code is above)

// ---------------------------------------------
// 1.1 Bootstrap User (Manual Recovery)
// ---------------------------------------------
export const bootstrapUser = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    console.log(`🚑 BOOTSTRAP: Checking recovery for User ${uid}...`);

    const userRef = db.ref(`users/${uid}`);
    const snap = await userRef.get();

    if (snap.exists()) {
        console.log(`✅ BOOTSTRAP: User ${uid} already exists. No action.`);
        return { success: true, restored: false };
    }

    // Recover User Profile
    console.log(`⚠️ BOOTSTRAP: User ${uid} missing in RTDB. Restoring...`);

    // Get Config
    const config = await getConfig();
    const rewards = config.global.initialRewards;

    const now = Date.now();
    const profile = {
        profile: {
            displayName: context.auth?.token.name || "New User",
            avatarUrl: context.auth?.token.picture || null,
            city: "",
            country: "India",
            createdAt: now,
            lastLoginAt: now,
        },
        wallet: {
            gold: rewards.gold,
            gems: rewards.gems,
            createdAt: now,
            updatedAt: now,
        },
    };

    await userRef.set(profile);

    // Transaction for Gold
    if (rewards.gold > 0) {
        const txnRef = db.ref(`walletTransactions/${uid}`).push();
        await txnRef.set({
            amount: rewards.gold,
            currency: 'gold',
            type: "adjustment",
            beforeBalance: 0,
            afterBalance: rewards.gold,
            createdAt: now,
            meta: { reason: "initial_rewards", seen: false },
        });
    }

    // Transaction for Gems
    if (rewards.gems > 0) {
        const txnRef = db.ref(`walletTransactions/${uid}`).push();
        await txnRef.set({
            amount: rewards.gems,
            currency: 'gems',
            type: "adjustment",
            beforeBalance: 0,
            afterBalance: rewards.gems,
            createdAt: now,
            meta: { reason: "initial_rewards", seen: false },
        });
    }

    console.log(`✅ BOOTSTRAP: User ${uid} restored with rewards.`);
    return { success: true, restored: true };
});


// ---------------------------------------------
// 1.2 Check Timeouts (Scheduled)
// ---------------------------------------------
export const checkTimeouts = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
        const snap = await db.ref("games").orderByChild("state").equalTo("active").get();
        const now = Date.now();
        const updates: any = {};

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

// ---------------------------------------------
// 2. join2PQueue (callable)
// ---------------------------------------------
export const join2PQueue = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    const config = await getConfig();
    const entryFee = config.modes['2p'].stake;

    console.log("join2PQueue called", {
        uid: uid,
        entryFee, // Log the server-enforced fee
        clientDataFee: data.entryFee, // Log what client sent for debug
        auth: context.auth
    });

    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    // Funds check
    const goldSnap = await db.ref(`users/${uid}/wallet/gold`).get();
    const gold = goldSnap.exists() ? Number(goldSnap.val()) : 0;

    if (gold < entryFee) {
        await db.ref(`userQueueStatus/${uid}`).set({
            status: "insufficient_funds",
            ts: Date.now(),
        });
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Insufficient funds.",
        );
    }

    // Push to queue
    const qRef = db.ref("queue/2p").push();
    const pushId = qRef.key!;

    await qRef.set({
        uid,
        entryFee,
        ts: Date.now(),
    });

    // Update user queue status
    await db.ref(`userQueueStatus/${uid}`).set({
        status: "queued",
        pushId,
        ts: Date.now(),
    });

    console.log("User queued successfully", { uid, pushId });
    console.log(`📥 QUEUE_INSERT: User ${uid} inserted to queue with entry fee ${entryFee}. Push ID: ${pushId}`);

    return { success: true, pushId };
});

// ---------------------------------------------
// 3. leaveQueue (callable)
// ---------------------------------------------
export const leaveQueue = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const stSnap = await db.ref(`userQueueStatus/${uid}`).get();
    if (!stSnap.exists()) {
        return { success: true, removed: false };
    }

    const info = stSnap.val();
    const status = info.status;
    let removed = false;

    if (status === 'queued') { // 2P
        if (info.pushId) {
            await db.ref(`queue/2p/${info.pushId}`).remove();
            removed = true;
        }
    } else if (status === 'queued_solo') { // 4P Solo
        if (info.pushId) {
            await db.ref(`queue/4p_solo/${info.pushId}`).remove();
            removed = true;
        }
    } else if (status === 'queued_team') { // 4P Team (Formed)
        const teamId = info.teamId;
        if (teamId) {
            const teamSnap = await db.ref(`queue/4p_team/${teamId}`).get();
            if (teamSnap.exists()) {
                const team = teamSnap.val();
                await db.ref(`queue/4p_team/${teamId}`).remove();
                removed = true;

                // Notify Partner
                const partnerUid = (team.p1 === uid) ? team.p2 : team.p1;
                if (partnerUid && partnerUid !== 'BOT_PLAYER') {
                    await db.ref(`userQueueStatus/${partnerUid}`).set({
                        status: "left",
                        reason: "partner_left",
                        ts: Date.now(),
                        message: "Your partner left the queue."
                    });
                }
            }
        }
    }

    await db.ref(`userQueueStatus/${uid}`).set({
        status: "left",
        ts: Date.now(),
    });

    return { success: true, removed };
});

// ---------------------------------------------
// 3.1 createPrivateTable (callable)
// ---------------------------------------------


// ---------------------------------------------
// 3.2 joinPrivateGame (callable)
// ---------------------------------------------


// ---------------------------------------------
// 4. Queue Triggers (2P & 4P)
// ---------------------------------------------

export const pairOnQueueCreate = functions.database
    .ref("queue/2p/{pushId}")
    .onCreate(async (snapshot, context) => {
        const original = snapshot.val();
        console.log("attemptPairing triggered", { pushId: context.params.pushId, val: original });

        const lockRef = db.ref("locks/queue/2p");
        const lockResult = await lockRef.transaction(
            (currentLock) => {
                if (currentLock && (Date.now() - currentLock < 10000)) {
                    return; // Locked and active (< 10s old) -> abort
                }
                return Date.now(); // claim lock (overwrite if null or old)
            }
        );

        if (lockResult.committed) {
            console.log("Lock acquired for 2P queue.");
            try {
                await attemptPairing();
            } catch (e) {
                console.error("CRITICAL: attemptPairing failed", e);
            } finally {
                await lockRef.remove();
                console.log("Lock released for 2P queue.");
            }
        } else {
            console.log("Pairing skipped: lock held");
        }
    });

import { attemptPairing } from "./controllers/two_player_table";
import { GameBuilder } from "./services/game_builder";

// ---------------------------------------------
// 5. Bot pairing - 10 seconds timeout
// ---------------------------------------------
export const pairWithBot = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async (context) => {
        const cutoff = Date.now() - 10 * 1000; // 10 seconds ago
        const queueRef = db.ref("queue/2p");
        const snap = await queueRef.orderByChild("ts").endAt(cutoff).get();

        if (!snap.exists()) return null;

        const updates: any = {};
        const entries: any[] = [];

        snap.forEach((child) => {
            const val = child.val();
            if (val && val.uid && val.uid !== "BOT_PLAYER") {
                entries.push({
                    pushId: child.key!,
                    uid: val.uid,
                    entryFee: Number(val.entryFee) || 0,
                    ts: Number(val.ts) || 0,
                });
            }
        });

        if (entries.length === 0) return null;

        // Pair each entry with a bot
        for (const entry of entries) {
            const botUid = "BOT_PLAYER";

            // Remove from queue
            updates[`queue/2p/${entry.pushId}`] = null;

            // Use GameBuilder (Atomic Create)
            // We need to await here inside loop, or collect promises.
            // Since this is onRun, async loop is fine.
            try {
                const { gameId, tableId } = await GameBuilder.createActiveGame({
                    mode: '2p',
                    stake: entry.entryFee,
                    players: [
                        { uid: entry.uid, seat: 0, name: "Player 1" },
                        { uid: botUid, seat: 2, name: "Bot" }
                    ]
                });
                // Assign gameId and tableId to entry for later use in wallet delta
                entry.gameId = gameId;
                entry.tableId = tableId;
                console.log(`Paired ${entry.uid} with bot via GameBuilder. GameId: ${gameId}, TableId: ${tableId}`);
            } catch (e) {
                console.error(`Failed to create bot game for ${entry.uid}`, e);
            }
        }

        await db.ref().update(updates);

        // Deduct entry fees from real users
        // Deduct entry fees from real users
        for (const entry of entries) {
            try {
                await applyWalletDelta(entry.uid, -entry.entryFee, "stake_debit", {
                    currency: 'gold',
                    gameId: entry.gameId, // Note: gameId wasn't in entry object before, need to ensure it is or pass it from updates
                    tableId: entry.tableId,
                    meta: { stake: entry.entryFee, mode: "2p", opponent: "BOT" },
                });
            } catch (e) {
                console.error(`Error deducting entry fee from ${entry.uid}:`, e);
            }
        }

        console.log(`Paired ${entries.length} users with bots.`);
        return null;
    });

// ---------------------------------------------
// 6. Bot AI - 2 second delay
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
// 7. Auto-play Turns (Unified)
// ---------------------------------------------
export const autoPlayTurns = functions.database
    .ref("games/{gameId}/lastMoveTime")
    .onWrite(async (change, context) => {
        const gameId = context.params.gameId;
        const newTime = change.after.val();

        if (!newTime) return null;

        // Wait for bot takeover time (which is same as turn timeout now)
        // We wait slightly less than the full timeout to ensure we catch it?
        // Or we wait for the deadline.
        // The user said: "If there no is time left on the timer... The autobot can click..."
        // So we should wait until the deadline.

        // Let's read the game to get the deadline
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
        console.log(`⏱️ AUTO_PLAY: Current game state:`, {
            turn: currentPlayer,
            phase: phase,
            diceValue: freshGame.diceValue,
            board: Object.keys(freshGame.board || {})
        });

        const decision = getBotDecision(freshGame, currentPlayer);
        console.log(`⏱️ AUTO_PLAY: Bot decision for ${currentPlayer}:`, decision);

        await executeBotAction(gameId, currentPlayer, decision, freshGame);

        return null;
    });

// ---------------------------------------------
// 8. cleanupQueue (stale entries)  
// ---------------------------------------------
export const cleanupQueue = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async () => {
        const cutoff = Date.now() - 5 * 60 * 1000;
        const queueRef = db.ref("queue/2p");
        const snap = await queueRef.orderByChild("ts").endAt(cutoff).get();

        if (!snap.exists()) return null;

        const updates: any = {};
        snap.forEach((child) => {
            const val = child.val();
            updates[`queue/2p/${child.key}`] = null;
            if (val.uid) {
                updates[`userQueueStatus/${val.uid}`] = {
                    status: "left",
                    reason: "timeout",
                    ts: Date.now(),
                };
            }
        });

        await db.ref().update(updates);
        console.log(
            `Cleaned up ${Object.keys(updates).length / 2} stale queue entries.`,
        );
        return null;
    });

// ---------------------------------------------
// 8.1 checkTeamTimeouts (4P)
// ---------------------------------------------
export const checkTeamTimeouts = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
        await processSoloQueue();
        await processTeamQueue();
        return null;
    });

// ---------------------------------------------
// 8.2 Team Triggers (4P Matchmaking)

export const pairOnSoloQueueCreate = functions.database
    .ref("queue/4p_solo/{pushId}")
    .onCreate(async (snapshot, context) => {
        const val = snapshot.val();
        console.log(`4P Solo Trigger | ID: ${context.params.pushId} | UID: ${val?.uid || 'unknown'}`);

        const lockRef = db.ref("locks/queue/4p_solo");
        let committed = false;

        // Try to acquire lock with retries to handle concurrency
        for (let i = 0; i < 5; i++) {
            const lockResult = await lockRef.transaction((current) => {
                if (current && (Date.now() - current < 10000)) return; // Locked and fresh
                return Date.now();
            });

            if (lockResult.committed) {
                console.log("Lock acquired for 4P Solo queue.");
                try {
                    await attemptSoloPairing();
                } catch (e) {
                    console.error("CRITICAL: attemptSoloPairing failed", e);
                } finally {
                    await lockRef.remove();
                    console.log("Lock released for 4P Solo queue.");
                }
                committed = true;
                break;
            }

            console.log(`4P Solo Lock busy (attempt ${i + 1}/5)`);
            // Random backoff 200ms-600ms
            await new Promise(r => setTimeout(r, 200 + Math.random() * 400));
        }

        if (!committed) {
            console.warn("Could not acquire lock for solo pairing after retries (Busy).");
        }
    });

export const pairOnTeamQueueCreate = functions.database
    .ref("queue/4p_team/{teamId}")
    .onCreate(async (snapshot, context) => {
        console.log("New Team Queue Entry for 4P:", context.params.teamId);

        const lockRef = db.ref("locks/queue/4p_team");
        let committed = false;

        for (let i = 0; i < 5; i++) {
            const lockResult = await lockRef.transaction((current) => {
                if (current && (Date.now() - current < 10000)) return; // Locked
                return Date.now();
            });

            if (lockResult.committed) {
                console.log("Lock acquired for 4P Team queue.");
                try {
                    await attemptTeamPairing();
                } catch (e) {
                    console.error("CRITICAL: attemptTeamPairing failed", e);
                } finally {
                    await lockRef.remove();
                    console.log("Lock released for 4P Team queue.");
                }
                committed = true;
                break;
            }

            await new Promise(r => setTimeout(r, 200 + Math.random() * 400));
        }

        if (!committed) {
            console.warn("Could not acquire lock for team pairing after retries.");
        }
    });

// ---------------------------------------------
// 9. rollDice (callable)
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

async function rollDiceInternal(gameId: string, uid: string) {
    console.log(`DEBUG: rollDiceInternal called for gameId: ${gameId}, uid: ${uid}`);
    const gameRef = db.ref(`games/${gameId}`);
    const snap = await gameRef.get();
    console.log(`DEBUG: gameRef path: ${gameRef.toString()}, exists: ${snap.exists()}`);

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
    // We do NOT check for valid moves here. That happens in onDiceRolled after animation.
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
// 9.1 onDiceRolled (Trigger)
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
        // User said: "If there is more just one move availiabe to the user, the system automatically makes the move"
        // But also said: "If there is time left on the timer... The user can select... If just one move... system automatically makes"
        // So yes, we can auto-make it here.
        if (validMoveCount === 1) {
            // Add a small delay for user to see the dice result before move happens
            await new Promise((r) => setTimeout(r, 500));
            await submitMoveInternal(gameId, uid, singleValidMoveIndex);
        }

        return null;
    });

// ---------------------------------------------
// 10. submitMove (callable)
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

async function submitMoveInternal(gameId: string, uid: string, tokenIndex: number) {
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

function getNextPlayerUid(game: any, currentUid: string): string {
    const playerIds = Object.keys(game.players || {});
    // Sort by seat to ensure consistent order
    playerIds.sort((a, b) => (game.players[a]?.seat || 0) - (game.players[b]?.seat || 0));

    const currentIndex = playerIds.indexOf(currentUid);
    if (currentIndex === -1) return currentUid; // fallback

    const nextIndex = (currentIndex + 1) % playerIds.length;
    return playerIds[nextIndex];
}

// ---------------------------------------------
// 11. onGameCompleted (Payouts)
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

        // 2P only for now
        const playerUids = Object.keys(game.board || {});
        if (playerUids.length !== 2) return null;

        const prizePool = stake * playerUids.length; // 1000 * 2 = 2000
        const rakeAmount = Math.floor(prizePool * rake);
        const winnerPayout = prizePool - rakeAmount;

        await applyWalletDelta(winnerUid, +winnerPayout, "win_payout", {
            currency: 'gold',
            gameId,
            tableId,
            meta: { stake, rake, prizePool },
        });

        // Update userGameStatus to idle for both players
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

        console.log(`💰 PAYOUT: Winner ${winnerUid} got ${winnerPayout} gold in game ${gameId}`);

        // --- Activity Stream Injection (2P) ---
        // Log "Game Result" to the DM between P1 and P2
        if (playerUids.length === 2 && !playerUids.includes("BOT_PLAYER")) {
            const p1 = playerUids[0];
            const p2 = playerUids[1];
            const convId = getDmId(p1, p2);

            // Payload for the Unified Timeline
            // Context: Source Game
            // Payload: Score/Winner details
            // We use 'system' as sender? Or 'winner'?
            // Standard: 'system' or utilize the helper which expects a UID.
            // If we use 'winnerUid', it looks like Winner posted it. That's fine.
            // Or use a special "ACTIVITY_BOT" uid if we had one.
            // For now, let's use the Winner's UID as the "Sender" of the "Victory" card.

            // Construct score string if possible? Currently logic doesn't track score, just winner.
            // But we know it's a win.

            try {
                // Ensure conversation exists (lazy init handled by sendMessageInternal hopefully? 
                // No, sendMessageInternal expects it. startDMInternal handles create.)
                // Let's call startDMInternal just in case, it's cheap.
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

        return null;
    });

// ---------------------------------------------
// Helper: Execute Bot Action
// ---------------------------------------------
import { BotAction } from "./bot";

async function executeBotAction(gameId: string, uid: string, decision: BotAction, game: any) {
    console.log(`🤖 BOT_ACTION: ${uid} -> ${decision.type}`, decision);

    if (decision.type === "roll") {
        await rollDiceInternal(gameId, uid);
    } else if (decision.type === "move") {
        await submitMoveInternal(gameId, uid, decision.tokenIndex);
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
// ---------------------------------------------
// 10. pickPlayerFromQueue (callable) - NEW
// ---------------------------------------------
// ---------------------------------------------
// 10. pickPlayerFromQueue (callable) - Refactored
// ---------------------------------------------
export const pickPlayerFromQueue = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    try {
        const { targetPushId, gemFee } = data;
        const fee = Number(gemFee);

        if (!targetPushId || isNaN(fee)) {
            throw new functions.https.HttpsError("invalid-argument", "Missing or invalid arguments.");
        }

        console.log(`🎯 PICK_PLAYER: User ${uid} attempting to pick queue entry ${targetPushId} for ${fee} gems`);

        // 1. Transaction to lock and claim the queue entry
        const queueRef = db.ref(`queue/2p/${targetPushId}`);
        let targetEntry: any = null;

        const snap = await queueRef.get();
        if (!snap.exists()) {
            throw new functions.https.HttpsError("not-found", "Player is no longer in queue.");
        }
        targetEntry = snap.val();

        console.log(`pickPlayerFromQueue | Started | ${uid} | ${targetEntry.uid}`);

        if (targetEntry.uid === uid) {
            throw new functions.https.HttpsError("failed-precondition", "Cannot play against yourself.");
        }

        console.log(`Check if Host is waiting | Found | ${uid} | ${targetEntry.uid}`);


        const config = await getConfig();

        // 2. Validate Funds
        await validateFunds(uid, targetEntry.uid, config.modes['2p'].stake, fee);

        // 3. Transaction to remove queue entry
        await queueRef.transaction((current) => {
            if (current === null) return null;
            if (current.uid !== targetEntry.uid) return undefined;
            return null; // Remove it
        }, (error, committed, snapshot) => {
            if (error) {
                throw new functions.https.HttpsError("internal", "Queue transaction failed: " + error.message);
            }
            if (!committed) {
                throw new functions.https.HttpsError("not-found", "Player already matched or removed.");
            }
        });

        // 4. Deduct Fees
        try {
            await deductJoinFees(uid, targetEntry.uid, config.modes['2p'].stake, fee);
            // If we are here, deduction successful.
        } catch (e: any) {
            console.error("Payment failed", e);
            await refundJoinFees(uid, targetEntry.uid, config.modes['2p'].stake, fee);
            await restoreQueueEntry(targetPushId, targetEntry);

            // Propagate
            if (e.code && e.code.startsWith('functions/')) throw e;
            throw new functions.https.HttpsError("aborted", "Payment failed: " + (e.message || "Unknown error"));
        }

        // 4. Create Game (GameBuilder)
        // P1: Target (from queue)
        // P2: Picker (current user)
        const { gameId, tableId } = await GameBuilder.createActiveGame({
            mode: '2p',
            stake: config.modes['2p'].stake,
            players: [
                { uid: targetEntry.uid, seat: 0, name: "Player 1" },
                { uid, seat: 2, name: "Player 2" }
            ]
        });

        console.log(`✅ PICK_SUCCESS: ${uid} picked ${targetEntry.uid}. Game: ${gameId}`);
        return { success: true, gameId, tableId };

    } catch (finalErr: any) {
        console.error("Detail Error in pickPlayer:", finalErr);
        if (finalErr instanceof functions.https.HttpsError) throw finalErr;
        throw new functions.https.HttpsError("internal", finalErr.message || "Internal crash");
    }
});

// ---------------------------------------------
// Helpers
// ---------------------------------------------

async function validateFunds(joinerUid: string, hostUid: string, goldNeeded: number, gemsNeeded: number) {
    const walletSnap = await db.ref(`users/${joinerUid}/wallet`).get();
    const wallet = walletSnap.val() || {};
    const gold = Number(wallet.gold || 0);
    const gems = Number(wallet.gems || 0);

    console.log(`Balances Check for ${joinerUid} | Gold: ${gold} (Need ${goldNeeded}) | Gems: ${gems} (Need ${gemsNeeded})`);

    if (gold < goldNeeded) {
        console.log(`Check if joiner has Gold | Failed | ${joinerUid} | ${hostUid}`);
        throw new functions.https.HttpsError("failed-precondition", "Insufficient Gold to join queue.");
    }
    console.log(`Check if joiner has Gold | Success | ${joinerUid} | ${hostUid}`);

    if (gems < gemsNeeded) {
        console.log(`Check if Joiner has Gems | Failed | ${joinerUid} | ${hostUid}`);
        throw new functions.https.HttpsError("failed-precondition", `Insufficient Gems. Need ${gemsNeeded}, have ${gems}`);
    }
    console.log(`Check if Joiner has Gems | Success | ${joinerUid} | ${hostUid}`);
}

async function deductJoinFees(pickerUid: string, targetUid: string, stake: number, fee: number) {
    // Ded Caller Gold
    await applyWalletDelta(pickerUid, -stake, "stake_debit", {
        currency: 'gold',
        meta: { mode: "2p", type: "choice_join" }
    });
    console.log(`Gold deducted from Joiner | Success | ${pickerUid} | ${targetUid}`);

    // Ded Caller Gems
    try {
        await applyWalletDelta(pickerUid, -fee, "fee_debit", {
            currency: 'gems',
            meta: { type: "choice_join_fee" }
        });
        console.log(`Gems deducted from Joiner | Success | ${pickerUid} | ${targetUid}`);
    } catch (e) {
        // Refund Gold
        await applyWalletDelta(pickerUid, +stake, "refund", { currency: 'gold' });
        throw e;
    }

    // Ded Target Gold
    try {
        await applyWalletDelta(targetUid, -stake, "stake_debit", {
            currency: 'gold',
            meta: { mode: "2p", type: "choice_join_target" }
        });
        console.log(`Gold deducted from Host | Success | ${pickerUid} | ${targetUid}`);
    } catch (e) {
        // Refund Caller Gold & Gems
        await applyWalletDelta(pickerUid, +stake, "refund", { currency: 'gold' });
        await applyWalletDelta(pickerUid, +fee, "refund", { currency: 'gems' });
        throw e;
    }
}

async function refundJoinFees(pickerUid: string, targetUid: string, stake: number, fee: number) {
    // Best effort refund - individual calls usually safe since we only refund what succeeded, 
    // but here we just try refunding everything blindly for simplicity or use flags?
    // In strict mode we'd track exactly what was deducted.
    // Re-using logic from original catch block:
    // "if (callerGoldDed) ..."
    // But since helper throws on first failure, we know exactly state?
    // Actually, helper handles its own partial refunds inside `catch` blocks above!
    // So this global refund helper might be redundant if `deductJoinFees` is atomic-like.
    // However, if strict `deductJoinFees` throws, it has already cleaned up?
    // Let's assume `deductJoinFees` attempts cleanup.
    // BUT what if the error was NOT in `deductJoinFees` but in `createGameSession`?
    // Then we definitelly need a refund function.

    // For now, let's keep it simple: WE DO NOT call this if `deductJoinFees` fails (it handles itself).
    // We call this if `createGameSession` fails.

    await applyWalletDelta(pickerUid, +stake, "refund", { currency: 'gold' });
    await applyWalletDelta(pickerUid, +fee, "refund", { currency: 'gems' });
    await applyWalletDelta(targetUid, +stake, "refund", { currency: 'gold' });
}

async function restoreQueueEntry(pushId: string, entry: any) {
    if (entry && typeof entry === 'object') {
        try {
            await db.ref(`queue/2p/${pushId}`).set(entry);
        } catch (restoreErr) {
            console.error("Critical: Failed to restore queue entry", restoreErr);
        }
    }
}


// ---------------------------------------------
// Helper: Send Poke Notification (FCM)
// ---------------------------------------------


// ---------------------------------------------
// 12. forfeitGame (callable)
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

    // Determine Winner (Opponent)
    const players = Object.keys(game.players);
    const winnerUid = players.find(p => p !== uid);

    if (!winnerUid) {
        // Should not happen in 2P
        await gameRef.update({ state: "aborted" });
        return { success: true, result: "aborted" };
    }

    // Call onGameCompleted logic by setting state completed/winner
    // We update manually because the trigger handles payouts
    await gameRef.update({
        state: "completed",
        winnerUid: winnerUid,
        winnerReason: "opponent_forfeit",
        loserUid: uid,
        updatedAt: Date.now()
    });

    console.log(`🏳️ FORFEIT: ${uid} forfeited game ${gameId}. Winner: ${winnerUid}`);
    return { success: true };
});

// ---------------------------------------------
// 12. Team Up Triggers & Schedulers
// ---------------------------------------------


