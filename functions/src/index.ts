import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.database();

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

    const profile = {
        gold: 1000,
        createdAt: Date.now(),
        lastLoginAt: Date.now(),
    };

    await userRef.set(profile);
    console.log(`✅ USER_CREATED: User ${uid} created with ${profile.gold} starting gold`);
    return null;
});

// ---------------------------------------------
// 2. join2PQueue (callable)
// ---------------------------------------------
export const join2PQueue = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const entryFee = Number(data.entryFee) || 0;

    // Funds check
    const goldSnap = await db.ref(`users/${uid}/gold`).get();
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
    const pushId = info.pushId;
    if (pushId) {
        await db.ref(`queue/2p/${pushId}`).remove();
    }

    await db.ref(`userQueueStatus/${uid}`).set({
        status: "left",
        ts: Date.now(),
    });

    return { success: true, removed: !!pushId };
});

// ---------------------------------------------
// 4. Pairing trigger (distinct users only)
// ---------------------------------------------
export const pairOnQueueCreate = functions.database
    .ref("queue/2p/{pushId}")
    .onCreate(async (snapshot, context) => {
        const original = snapshot.val();
        console.log("New queue entry", context.params.pushId, original);

        const lockRef = db.ref("locks/queue/2p");
        const lockResult = await lockRef.transaction(
            (currentLock) => {
                if (currentLock) {
                    return; // Locked by someone else -> abort
                }
                return Date.now(); // claim lock
            }
        );

        if (lockResult.committed) {
            try {
                await attemptPairing();
            } finally {
                await lockRef.remove();
            }
        }
    });

type QEntry = {
    pushId: string;
    uid: string;
    entryFee: number;
    ts: number;
};

async function attemptPairing() {
    const queueRef = db.ref("queue/2p");

    // Read up to first 20 entries ordered by ts
    const snap = await queueRef.orderByChild("ts").limitToFirst(20).get();
    if (!snap.exists()) {
        console.log("No entries in queue, nothing to pair.");
        return;
    }

    const allEntries: QEntry[] = [];
    snap.forEach((child) => {
        const val = child.val();
        if (!val || !val.uid) return;
        allEntries.push({
            pushId: child.key!,
            uid: String(val.uid),
            entryFee: Number(val.entryFee) || 0,
            ts: Number(val.ts) || 0,
        });
    });

    if (allEntries.length < 2) {
        console.log("Less than 2 queue entries, waiting.");
        return;
    }

    // Sort by time
    allEntries.sort((a, b) => a.ts - b.ts);

    // Distinct users only
    const distinct: QEntry[] = [];
    const seen = new Set<string>();
    for (const e of allEntries) {
        if (!seen.has(e.uid)) {
            seen.add(e.uid);
            distinct.push(e);
        }
        if (distinct.length === 2) break;
    }

    if (distinct.length < 2) {
        console.log("Not enough distinct users to pair yet.");
        return;
    }

    const p1 = distinct[0];
    const p2 = distinct[1];

    if (p1.uid === p2.uid) {
        console.log("Same uid for two entries, refusing to pair:", p1.uid);
        return;
    }

    const k1 = p1.pushId;
    const k2 = p2.pushId;

    console.log(`🎮 USER_MATCHED: User ${p1.uid} matched with User ${p2.uid}`);
    console.log(`Pairing users ${p1.uid} and ${p2.uid}`);

    // Create table & game
    const tableRef = db.ref("tables").push();
    const gameRef = db.ref("games").push();
    const tableId = tableRef.key!;
    const gameId = gameRef.key!;

    const initialBoard = {
        [p1.uid]: [-1, -1, -1, -1],
        [p2.uid]: [-1, -1, -1, -1],
    };

    const now = Date.now();

    const updates: any = {};

    // Remove from queue
    updates[`queue/2p/${k1}`] = null;
    updates[`queue/2p/${k2}`] = null;

    console.log(`📋 TABLE_CREATED: Table ${tableId} created for game ${gameId} with users [${p1.uid}, ${p2.uid}]`);

    // Table
    updates[`tables/${tableId}`] = {
        gameId,
        mode: "2p",
        entryFee: p1.entryFee,
        players: {
            [p1.uid]: { seat: 0, name: "Player 1" },
            [p2.uid]: { seat: 1, name: "Player 2" },
        },
        status: "active",
        createdAt: now,
    };

    console.log(`🎲 GAME_CREATED: Game ${gameId} created with users [${p1.uid}, ${p2.uid}]`);

    // Game (minimal schema)
    updates[`games/${gameId}`] = {
        tableId,
        mode: "2p",
        players: {
            [p1.uid]: { seat: 0 },
            [p2.uid]: { seat: 1 },
        },
        board: initialBoard,
        turn: p1.uid,
        diceValue: 1,
        state: "active",
        lastMoveTime: now,
        createdAt: now,
        updatedAt: now,
    };

    // User queue status -> paired
    updates[`userQueueStatus/${p1.uid}`] = {
        status: "paired",
        tableId,
        gameId,
        ts: now,
    };
    updates[`userQueueStatus/${p2.uid}`] = {
        status: "paired",
        tableId,
        gameId,
        ts: now,
    };

    // Set current game for reconnect
    updates[`users/${p1.uid}/currentGameId`] = gameId;
    updates[`users/${p1.uid}/currentTableId`] = tableId;
    updates[`users/${p2.uid}/currentGameId`] = gameId;
    updates[`users/${p2.uid}/currentTableId`] = tableId;

    await db.ref().update(updates);

    // Deduct entry fees
    try {
        await db.ref(`users/${p1.uid}/gold`).transaction((gold) => {
            return (Number(gold) || 0) - p1.entryFee;
        });
        await db.ref(`users/${p2.uid}/gold`).transaction((gold) => {
            return (Number(gold) || 0) - p2.entryFee;
        });
        console.log(`Deducted ${p1.entryFee} from ${p1.uid} and ${p2.entryFee} from ${p2.uid}`);
    } catch (e) {
        console.error("Error deducting entry fees:", e);
    }

    console.log(`Paired ${p1.uid} and ${p2.uid} in game ${gameId}`);
}

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
            const tableRef = db.ref("tables").push();
            const gameRef = db.ref("games").push();
            const tableId = tableRef.key!;
            const gameId = gameRef.key!;

            const botUid = "BOT_PLAYER";
            const now = Date.now();

            // Remove from queue
            updates[`queue/2p/${entry.pushId}`] = null;

            // Create Table
            updates[`tables/${tableId}`] = {
                gameId,
                mode: "2p",
                entryFee: entry.entryFee,
                players: {
                    [entry.uid]: { seat: 0, name: "Player 1" },
                    [botUid]: { seat: 1, name: "Bot" },
                },
                status: "active",
                createdAt: now,
            };

            // Create Game
            updates[`games/${gameId}`] = {
                tableId,
                mode: "2p",
                players: {
                    [entry.uid]: { seat: 0 },
                    [botUid]: { seat: 1 },
                },
                board: {
                    [entry.uid]: [-1, -1, -1, -1],
                    [botUid]: [-1, -1, -1, -1],
                },
                turn: entry.uid,
                diceValue: 1,
                state: "active",
                isBotGame: true,
                lastMoveTime: now,
                createdAt: now,
                updatedAt: now,
            };

            // Update User Status
            updates[`userQueueStatus/${entry.uid}`] = {
                status: "paired",
                tableId,
                gameId,
                ts: now,
            };

            // Set current game for user
            updates[`users/${entry.uid}/currentGameId`] = gameId;
            updates[`users/${entry.uid}/currentTableId`] = tableId;

            console.log(`🤖 BOT_INSERTED: Bot player BOT_PLAYER created for game ${gameId}`);
            console.log(`🎮 USER_MATCHED: User ${entry.uid} matched with BOT_PLAYER`);
            console.log(`📋 TABLE_CREATED: Table ${tableId} created for game ${gameId} with users [${entry.uid}, BOT_PLAYER]`);
            console.log(`🎲 GAME_CREATED: Game ${gameId} created with users [${entry.uid}, BOT_PLAYER]`);
            console.log(`Paired ${entry.uid} with bot in game ${gameId}`);
        }

        await db.ref().update(updates);

        // Deduct entry fees from real users
        for (const entry of entries) {
            try {
                await db.ref(`users/${entry.uid}/gold`).transaction((gold) => {
                    return (Number(gold) || 0) - entry.entryFee;
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

        // Wait 2 seconds before bot moves
        await new Promise((r) => setTimeout(r, 2000));

        // Roll dice
        const diceValue = Math.floor(Math.random() * 6) + 1;

        // Get bot's tokens
        const botBoard = game.board?.BOT_PLAYER || [-1, -1, -1, -1];

        // Find valid tokens to move
        const validTokens: number[] = [];
        for (let i = 0; i < 4; i++) {
            const pos = botBoard[i];
            if (pos === -1 && diceValue === 6) {
                validTokens.push(i);
            } else if (pos >= 0 && pos < 57) {
                validTokens.push(i);
            }
        }

        // Pick random token
        let tokenIndex = 0;
        if (validTokens.length > 0) {
            tokenIndex = validTokens[Math.floor(Math.random() * validTokens.length)];
        } else {
            // No valid moves, switch turn
            const playerIds = Object.keys(game.players);
            const nextUid = playerIds.find((id) => id !== "BOT_PLAYER") || "BOT_PLAYER";

            await db.ref(`games/${gameId}`).update({
                turn: nextUid,
                diceValue,
                lastMoveTime: Date.now(),
                updatedAt: Date.now(),
            });
            return null;
        }

        // Execute move
        const currentPos = botBoard[tokenIndex];
        let newPos = currentPos;

        if (currentPos === -1) {
            if (diceValue === 6) {
                newPos = 0;
            }
        } else {
            newPos = currentPos + diceValue;
            if (newPos > 57) {
                newPos = 57;
            }
        }

        // Update game
        const updates: any = {};
        updates[`board/BOT_PLAYER/${tokenIndex}`] = newPos;
        updates[`diceValue`] = diceValue;
        updates[`lastMove`] = {
            uid: "BOT_PLAYER",
            tokenIndex,
            from: currentPos,
            to: newPos,
            ts: Date.now(),
        };
        updates[`lastMoveTime`] = Date.now();
        updates[`updatedAt`] = Date.now();

        // Check win
        botBoard[tokenIndex] = newPos;
        const allFinished = botBoard.every((p: number) => p >= 57);

        if (allFinished) {
            updates[`state`] = "completed";
            updates[`winnerUid`] = "BOT_PLAYER";
        } else {
            // Switch turn
            const playerIds = Object.keys(game.players);
            const nextUid = playerIds.find((id) => id !== "BOT_PLAYER") || "BOT_PLAYER";

            if (diceValue === 6 && !allFinished) {
                updates[`turn`] = "BOT_PLAYER";
            } else {
                updates[`turn`] = nextUid;
            }
        }

        await db.ref(`games/${gameId}`).update(updates);
        console.log(`Bot made move in game ${gameId}: token ${tokenIndex} from ${currentPos} to ${newPos}`);

        return null;
    });

// ---------------------------------------------
// 7. Auto-move timeout - 5 seconds
// ---------------------------------------------
export const autoMoveTimeout = functions.database
    .ref("games/{gameId}/lastMoveTime")
    .onWrite(async (change, context) => {
        const gameId = context.params.gameId;
        const newTime = change.after.val();

        if (!newTime) return null;

        // Wait 5 seconds
        await new Promise((r) => setTimeout(r, 5000));

        // Check if game still hasn't moved
        const gameRef = db.ref(`games/${gameId}`);
        const gameSnap = await gameRef.get();

        if (!gameSnap.exists()) return null;

        const game = gameSnap.val();

        // If lastMoveTime changed or game ended, someone moved
        if (game.lastMoveTime !== newTime || game.state !== "active") {
            return null;
        }

        // If it's bot's turn, let botTurn handle it
        if (game.turn === "BOT_PLAYER") {
            return null;
        }

        console.log(`⏱️ AUTO_MOVE: User ${game.turn} timed out, auto-moving...`);

        // Auto-move using bot logic
        const currentPlayer = game.turn;
        const board = game.board || {};
        const playerTokens = board[currentPlayer] || [-1, -1, -1, -1];

        const diceValue = Math.floor(Math.random() * 6) + 1;

        // Find valid moves
        const validTokens: number[] = [];
        for (let i = 0; i < 4; i++) {
            const pos = playerTokens[i];
            if (pos === -1 && diceValue === 6) {
                validTokens.push(i);
            } else if (pos >= 0 && pos < 57) {
                validTokens.push(i);
            }
        }

        let tokenIndex = 0;
        if (validTokens.length > 0) {
            tokenIndex = validTokens[Math.floor(Math.random() * validTokens.length)];
        } else {
            // No valid moves, switch turn
            const playerIds = Object.keys(game.players);
            const nextUid = playerIds.find((id) => id !== currentPlayer) || currentPlayer;

            await gameRef.update({
                turn: nextUid,
                diceValue,
                lastMoveTime: Date.now(),
                updatedAt: Date.now(),
            });
            return null;
        }

        // Execute move
        const currentPos = playerTokens[tokenIndex];
        let newPos = currentPos;

        if (currentPos === -1) {
            if (diceValue === 6) {
                newPos = 0;
            }
        } else {
            newPos = currentPos + diceValue;
            if (newPos > 57) {
                newPos = 57;
            }
        }

        const updates: any = {};
        updates[`board/${currentPlayer}/${tokenIndex}`] = newPos;
        updates[`diceValue`] = diceValue;
        updates[`lastMove`] = {
            uid: currentPlayer,
            tokenIndex,
            from: currentPos,
            to: newPos,
            auto: true,
            ts: Date.now(),
        };
        updates[`lastMoveTime`] = Date.now();
        updates[`updatedAt`] = Date.now();

        // Check win
        playerTokens[tokenIndex] = newPos;
        const allFinished = playerTokens.every((p: number) => p >= 57);

        if (allFinished) {
            updates[`state`] = "completed";
            updates[`winnerUid`] = currentPlayer;

            // Credit prize
            const entryFee = 100;
            const prize = entryFee * 2 * 0.9;

            await db.ref(`users/${currentPlayer}/gold`).transaction((gold) => {
                return (Number(gold) || 0) + prize;
            });

            await db.ref(`walletHistory/${currentPlayer}`).push({
                type: "win",
                amount: prize,
                gameId,
                ts: Date.now(),
            });

            // Clear currentGameId
            await db.ref(`users/${currentPlayer}/currentGameId`).remove();
            await db.ref(`users/${currentPlayer}/currentTableId`).remove();
        } else {
            // Switch turn
            const playerIds = Object.keys(game.players);
            const nextUid = playerIds.find((id) => id !== currentPlayer) || currentPlayer;

            if (diceValue === 6 && !allFinished) {
                updates[`turn`] = currentPlayer;
            } else {
                updates[`turn`] = nextUid;
            }
        }

        await gameRef.update(updates);
        console.log(`Auto-moved for ${currentPlayer}: token ${tokenIndex} from ${currentPos} to ${newPos}`);

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
// 9. submitMove (minimal Ludo + win condition)
// ---------------------------------------------
export const submitMove = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const gameId = String(data.gameId || "");
    const tokenIndex = Number(data.tokenIndex);
    const diceValue = Number(data.diceValue);

    if (!gameId) {
        throw new functions.https.HttpsError("invalid-argument", "gameId required.");
    }
    if (!Number.isInteger(tokenIndex) || tokenIndex < 0 || tokenIndex > 3) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "tokenIndex must be 0..3.",
        );
    }
    if (!Number.isInteger(diceValue) || diceValue < 1 || diceValue > 6) {
        throw new functions.https.HttpsError("invalid-argument", "diceValue 1..6.");
    }

    const gameRef = db.ref(`games/${gameId}`);
    const gameSnap = await gameRef.get();
    if (!gameSnap.exists()) {
        throw new functions.https.HttpsError("not-found", "Game not found.");
    }

    const game = gameSnap.val();

    if (game.state === "completed") {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Game already completed.",
        );
    }

    if (!game.players || !game.players[uid]) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "You are not a player in this game.",
        );
    }

    if (game.turn !== uid) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Not your turn.",
        );
    }

    // Board structure: board[uid] = [p0,p1,p2,p3]
    const board = (game.board || {}) as Record<string, number[]>;
    const myTokens = (board[uid] || [-1, -1, -1, -1]).slice();

    const currentPos = Number(myTokens[tokenIndex] ?? -1);
    let newPos = currentPos;

    if (currentPos < 0) {
        // Home: can only enter on 6
        if (diceValue === 6) {
            newPos = 0;
        } else {
            throw new functions.https.HttpsError(
                "failed-precondition",
                "Need a 6 to leave home.",
            );
        }
    } else {
        newPos = currentPos + diceValue;
        if (newPos > 57) {
            newPos = 57;
        }
    }

    myTokens[tokenIndex] = newPos;
    board[uid] = myTokens;

    // Quick win condition: all tokens at or beyond 57
    let state = game.state || "active";
    let winnerUid = game.winnerUid || null;

    if (myTokens.every((p: number) => p >= 57)) {
        state = "completed";
        winnerUid = uid;

        // Credit prize
        const entryFee = 100;
        const prize = entryFee * 2 * 0.9;

        await db.ref(`users/${uid}/gold`).transaction((gold) => {
            return (Number(gold) || 0) + prize;
        });

        await db.ref(`walletHistory/${uid}`).push({
            type: "win",
            amount: prize,
            gameId,
            ts: Date.now(),
        });

        // Clear currentGameId for all players
        const playerIds = Object.keys(game.players);
        for (const playerId of playerIds) {
            if (playerId !== "BOT_PLAYER") {
                await db.ref(`users/${playerId}/currentGameId`).remove();
                await db.ref(`users/${playerId}/currentTableId`).remove();
            }
        }

        console.log(`Player ${uid} won game ${gameId}, awarded ${prize} gold`);
    }

    // Determine next turn
    const playerIds = Object.keys(game.players || {});
    const otherUid = playerIds.find((id) => id !== uid) || uid;
    const nextTurn = winnerUid ? uid : (diceValue === 6 && !winnerUid ? uid : otherUid);

    await gameRef.update({
        board,
        turn: nextTurn,
        diceValue,
        state,
        winnerUid: winnerUid || null,
        lastMoveTime: Date.now(),
        updatedAt: Date.now(),
    });

    return { success: true, state, winnerUid };
});

// ---------------------------------------------
// 10. hello test endpoint
// ---------------------------------------------
export const hello = onRequest((req, res) => {
    res.send("Hello from Tryb!");
});
