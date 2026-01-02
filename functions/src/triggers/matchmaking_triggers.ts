import * as functions from "firebase-functions";
import { db } from "../admin";
import { attemptPairing } from "../controllers/two_player_table";
import { GameBuilder } from "../services/game_builder";
import { applyWalletDelta } from "../utils";
import { processSoloQueue, processTeamQueue, attemptSoloPairing, attemptTeamPairing } from "../controllers/team_table";
import { GAME_TIMEOUT_MIN } from "../config";

// ---------------------------------------------
// pairOnQueueCreate (Trigger 2P)
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

// ---------------------------------------------
// pairWithBot (Scheduled)
// ---------------------------------------------
export const pairWithBot = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async (context) => {
        const cutoff = Date.now() - 30 * 1000; // 30 seconds ago
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
        for (const entry of entries) {
            try {
                await applyWalletDelta(entry.uid, -entry.entryFee, "stake_debit", {
                    currency: 'gold',
                    gameId: entry.gameId,
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
// cleanupQueue (Scheduled)
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
// checkTeamTimeouts (Scheduled 4P Process)
// ---------------------------------------------
export const checkTeamTimeouts = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async () => {
        await processSoloQueue();
        await processTeamQueue();
        return null;
    });

// ---------------------------------------------
// pairOnSoloQueueCreate (Trigger 4P Solo)
// ---------------------------------------------
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

// ---------------------------------------------
// pairOnTeamQueueCreate (Trigger 4P Team)
// ---------------------------------------------
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
            console.log(`4P Team Lock busy (attempt ${i + 1}/5)`);
            await new Promise(r => setTimeout(r, 200 + Math.random() * 400));
        }

        if (!committed) {
            console.warn("Could not acquire lock for Team pairing after retries.");
        }
    });
