import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig } from "../config";
import { GameBuilder } from "../services/game_builder";
import { applyWalletDelta } from "../utils";

// ---------------------------------------------
// join2PQueue (callable)
// ---------------------------------------------
export const join2PQueue = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    const config = await getConfig();
    const entryFee = config.modes['2p'].stake;

    console.log("join2PQueue called", {
        uid: uid,
        entryFee,
        clientDataFee: data.entryFee,
        auth: context.auth
    });

    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    // Funds check & Profile Fetch
    const userSnap = await db.ref(`users/${uid}`).get();
    if (!userSnap.exists()) {
        throw new functions.https.HttpsError("not-found", "User profile not found.");
    }
    const userData = userSnap.val();
    const gold = Number(userData.wallet?.gold || 0);
    const name = userData.displayName || "Player";
    const avatar = userData.photoURL || "";

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
        name,
        avatar,
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
// leaveQueue (callable)
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
// pickPlayerFromQueue (callable)
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
        } catch (e: any) {
            console.error("Payment failed", e);
            await refundJoinFees(uid, targetEntry.uid, config.modes['2p'].stake, fee);
            await restoreQueueEntry(targetPushId, targetEntry);

            if (e.code && e.code.startsWith('functions/')) throw e;
            throw new functions.https.HttpsError("aborted", "Payment failed: " + (e.message || "Unknown error"));
        }

        // 4. Create Game (GameBuilder)
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
