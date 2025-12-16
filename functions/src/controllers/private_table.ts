import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig } from "../config";
import { applyWalletDelta, sendPokeNotification } from "../utils";
import { GameBuilder } from "../services/game_builder";

// ---------------------------------------------
// 3.1 createPrivateTable (callable)
// ---------------------------------------------
export const createPrivateTable = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const config = await getConfig();
    const stake = config.modes.private.stake;

    // Check funds
    const goldSnap = await db.ref(`users/${uid}/wallet/gold`).get();
    const gold = goldSnap.exists() ? Number(goldSnap.val()) : 0;
    if (gold < stake) {
        throw new functions.https.HttpsError("failed-precondition", "Insufficient funds.");
    }

    // Add to private queue
    // We use uid as key to ensure one private table per user
    const qRef = db.ref(`queue/private/${uid}`);

    // Clear any existing (shouldn't happen if UI blocks)
    await qRef.remove();

    const pushId = qRef.push().key!; // dummy child for uniformity if needed, but we use UID as key

    await qRef.set({
        uid,
        entryFee: stake,
        status: "waiting",
        ts: Date.now(),
        pushId: uid // reusing UID as identifier
    });
    console.log(`3. Host entry created in queue | ${uid} | waiting`);
    return { success: true, hostUid: uid };
});

// ---------------------------------------------
// 3.2 joinPrivateGame (callable)
// ---------------------------------------------
export const joinPrivateGame = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }
    const hostUid = data.hostUid;
    if (!hostUid) {
        throw new functions.https.HttpsError("invalid-argument", "Host UID required.");
    }

    if (hostUid === uid) {
        throw new functions.https.HttpsError("failed-precondition", "Cannot join your own table.");
    }

    console.log(`8. Guest join private | ${uid} -> ${hostUid}`);

    // 1. Check if Host is Waiting (Atomic Transaction)
    const qRef = db.ref(`queue/private/${hostUid}`);
    let hostEntry: any = null;

    console.log(`Attempting claim for Private Table`, { host: hostUid, guest: uid });

    const result = await qRef.transaction((current) => {
        if (current === null) return;
        if (current.status !== "waiting") return;

        // Claim by setting status to 'matched'
        return { ...current, status: "matched" };
    });

    if (!result.committed) {
        // Failed to match.
        // Check if entry exists but wrong status, or doesn't exist.
        const checkSnap = await db.ref(`queue/private/${hostUid}`).get();
        hostEntry = checkSnap.val();

        if (!hostEntry) {
            // Scenario A: No entry found at all
            console.log(`🔒 PRIVATE_FAIL: Entry not found for ${hostUid}`);

            // Maybe they are playing?
            const hostGameSnap = await db.ref(`userGameStatus/${hostUid}`).get();
            const hostGameVal = hostGameSnap.val();

            if (hostGameVal && hostGameVal.status === "playing") {
                // Scenario C: Host in Game -> Send Poke/Notification
                console.log(`🔒 PRIVATE_POKE: Host ${hostUid} is playing.`);
                await sendPokeNotification(hostUid, uid, "game_in_progress");
                return { status: "poked_busy" };
            } else {
                // Scenario B: Host Idle/Away -> Send Poke
                console.log(`🔒 PRIVATE_POKE: Host ${hostUid} is idle/away.`);
                await sendPokeNotification(hostUid, uid, "idle");
                return { status: "poked_idle" };
            }
        }
        console.warn(`Claim aborted due to status mismatch. Status: ${hostEntry.status}`);
    }

    // --- Proceed with Matching (Scenario A) ---
    console.log(`Claim successful. Matched ${uid} with host ${hostUid}`);

    const config = await getConfig();
    const stake = config.modes.private.stake; // Logic assumes fixed stake for private too

    // Deduct Funds
    console.log("Deducting gold for Private Table", { host: hostUid, guest: uid, amount: stake });
    try {
        await applyWalletDelta(uid, -stake, "stake_debit", {
            currency: 'gold', meta: { mode: "2p_private", host: hostUid }
        });
        await applyWalletDelta(hostUid, -stake, "stake_debit", {
            currency: 'gold', meta: { mode: "2p_private", host: hostUid }
        });
    } catch (e) {
        // Simple refund logic
        console.error("Private Match Fund Error", e);
        await applyWalletDelta(uid, +stake, "refund", { currency: 'gold' });
        await applyWalletDelta(hostUid, +stake, "refund", { currency: 'gold' });
        // Restore Host to Queue?
        // Actually, if we fail to charge, we should probably set them back to 'waiting' if possible,
        // but for now, we just abort. The host will have to recreate or we rely on client timeout.
        // To be safe, let's try to restore 'waiting' status for host.
        try {
            await qRef.update({ status: 'waiting' });
        } catch (ex) { console.error("Failed to restore host status", ex); }

        throw new functions.https.HttpsError("aborted", "Funds failed.");
    }

    // Create Game (Unified)
    const { gameId, tableId } = await GameBuilder.createActiveGame({
        mode: 'private',
        stake,
        players: [
            { uid: hostUid, seat: 0, name: "Host" },
            { uid, seat: 2, name: "Guest" }
        ]
    });

    console.log(`🔒 PRIVATE_GAME_STARTED: ${gameId} with ${hostUid} & ${uid}`);
    return { success: true, status: "matched", gameId, tableId };
});
