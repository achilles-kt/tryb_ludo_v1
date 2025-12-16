import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig } from "../config";
import { GameBuilder } from "../services/game_builder";
import { applyWalletDelta } from "../utils";

// ---------------------------------------------
// 1. sendInvite (Guest -> Host)
// ---------------------------------------------


// ---------------------------------------------
// Logic Helper: Send Invite
// ---------------------------------------------
export async function sendInviteLogic(guestUid: string, hostUid: string) {
    if (!hostUid) {
        console.error("DEBUG: No hostUid");
        throw new functions.https.HttpsError("invalid-argument", "Host UID required.");
    }
    if (hostUid === guestUid) {
        throw new functions.https.HttpsError("failed-precondition", "Cannot invite yourself.");
    }

    // Rate Limit / Existing Check
    const existingRef = db.ref("invites");
    console.log("DEBUG: Checking existing invites for", guestUid);

    const snapshot = await existingRef
        .orderByChild("guestUid")
        .equalTo(guestUid)
        .get();

    console.log("DEBUG: Existing check done. Entries:", snapshot.numChildren());

    let pendingCount = 0;
    snapshot.forEach((child) => {
        const val = child.val();
        if (val.hostUid === hostUid && val.status === "pending") {
            pendingCount++;
        }
    });

    if (pendingCount > 0) {
        console.warn("DEBUG: Already pending");
        throw new functions.https.HttpsError("resource-exhausted", "Invite already pending.");
    }

    // Create Invite
    const inviteRef = db.ref("invites").push();
    const inviteId = inviteRef.key!;
    const now = Date.now();

    console.log("DEBUG: Creating invite", inviteId);

    await inviteRef.set({
        id: inviteId,
        hostUid,
        guestUid,
        status: "pending",
        createdAt: now,
        updatedAt: now,
    });

    console.log(`INVITE_SENT: ${guestUid} -> ${hostUid} | ${inviteId}`);
    return { success: true, inviteId };
}

// ---------------------------------------------
// 1. sendInvite (Guest -> Host)
// ---------------------------------------------
export const sendInvite = functions.https.onCall(async (data, context) => {
    try {
        console.log("DEBUG: sendInvite called", { data, auth: context.auth });
        const uid = context.auth?.uid; // Guest
        if (!uid) {
            console.error("DEBUG: No UID");
            throw new functions.https.HttpsError("unauthenticated", "Login required.");
        }
        return await sendInviteLogic(uid, data.hostUid);
    } catch (e: any) {
        console.error("CRASH: sendInvite failed", e);
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError("internal", `Server Error: ${e.message}`, e);
    }
});

// ---------------------------------------------
// Logic Helper: Respond to Invite
// ---------------------------------------------
export async function respondToInviteLogic(hostUid: string, inviteId: string, response: string) {
    if (!inviteId || !response) throw new functions.https.HttpsError("invalid-argument", "Missing args.");

    console.log(`DEBUG: respondToInvite called for ${inviteId} with ${response} by ${hostUid}`);

    const inviteRef = db.ref(`invites/${inviteId}`);

    // Pre-flight check
    const snap = await inviteRef.get();
    if (!snap.exists()) {
        console.error(`DEBUG: Invite ${inviteId} does not exist (pre-check).`);
        throw new functions.https.HttpsError("not-found", "Invite not found.");
    }
    const val = snap.val();
    console.log(`DEBUG: Invite state before response:`, val);

    if (val.hostUid !== hostUid) {
        console.error(`DEBUG: Permission denied. Host: ${val.hostUid}, Responder: ${hostUid}`);
    }

    // Transaction to ensure atomic update
    let guestUid = "";
    let gameId = "";
    let tableId = "";

    const transactionResult = await inviteRef.transaction((current) => {
        if (current === null) {
            console.warn("DEBUG_TX: Current is null, seeding with pre-fetched data.");
            return val;
        }
        if (current.hostUid !== hostUid) {
            console.warn(`DEBUG_TX: Host mismatch. Current: ${current.hostUid}, Auth: ${hostUid}`);
            return; // Abort
        }
        if (current.status !== "pending") {
            console.warn(`DEBUG_TX: Status not pending. Status: ${current.status}`);
            return; // Abort
        }

        if (response === "reject") {
            return { ...current, status: "rejected", updatedAt: Date.now() };
        } else if (response === "accept") {
            return { ...current, status: "accepted", updatedAt: Date.now() };
        }
        console.warn(`DEBUG_TX: Invalid response type: ${response}`);
        return; // invalid response type
    });

    if (!transactionResult.committed) {
        console.error("DEBUG: Transaction failed (not committed). Snapshot:", transactionResult.snapshot?.val());

        // Re-fetch to give precise error
        const snapAfter = await inviteRef.get();
        if (!snapAfter.exists()) throw new functions.https.HttpsError("not-found", "Invite not found.");
        const valAfter = snapAfter.val();

        if (valAfter.hostUid !== hostUid) throw new functions.https.HttpsError("permission-denied", "Not your invite.");
        if (valAfter.status !== "pending") {
            console.warn(`DEBUG: Invite already ${valAfter.status}. Client should have refreshed.`);
            throw new functions.https.HttpsError("failed-precondition", `Invite already ${valAfter.status}.`);
        }
        throw new functions.https.HttpsError("aborted", "Update failed (unknown reason).");
    }

    const updatedInvite = transactionResult.snapshot.val();
    guestUid = updatedInvite.guestUid;

    if (response === "accept") {
        // --- Start Game Logic ---
        const config = await getConfig();
        const stake = config.modes.private.stake;

        // Deduct Funds (Atomically for both if possible, or sequential with rollback)
        try {
            await applyWalletDelta(hostUid, -stake, "stake_debit", {
                currency: 'gold', meta: { mode: "2p_invite", inviteId }
            });
            await applyWalletDelta(guestUid, -stake, "stake_debit", {
                currency: 'gold', meta: { mode: "2p_invite", inviteId }
            });
        } catch (e) {
            console.error("Invite Fund Error", e);
            // Refund (Partial or full)
            await inviteRef.update({ status: "failed_funds" });
            throw new functions.https.HttpsError("aborted", "Funds failed.");
        }

        // Create Game (Unified Architecture)
        const { gameId: gId, tableId: tId } = await GameBuilder.createActiveGame({
            mode: 'private',
            stake,
            players: [
                { uid: hostUid, seat: 0, name: "Host" }, // Host P1
                { uid: guestUid, seat: 2, name: "Guest" } // Guest P2
            ]
        });
        gameId = gId;
        tableId = tId;

        // Update Invite with Game Info
        await inviteRef.update({ gameId, tableId });
        console.log(`INVITE_ACCEPTED: ${inviteId} | Game: ${gameId}`);
    } else {
        console.log(`INVITE_REJECTED: ${inviteId}`);
    }

    return { success: true, status: response, gameId, tableId };
}

// ---------------------------------------------
// 2. respondToInvite (Host -> Guest)
// ---------------------------------------------
export const respondToInvite = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid; // Host
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Login required.");
    return await respondToInviteLogic(uid, data.inviteId, data.response);
});

// ---------------------------------------------
// 3. cancelInvite (Guest -> Host)
// ---------------------------------------------
export const cancelInvite = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid; // Guest
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Login required.");
    const { inviteId } = data;
    if (!inviteId) throw new functions.https.HttpsError("invalid-argument", "Missing inviteId.");
    console.log(`DEBUG: cancelInvite called for ${inviteId} by ${uid}`);
    const inviteRef = db.ref(`invites/${inviteId}`);
    // Pre-flight check for debugging
    const snap = await inviteRef.get();
    if (!snap.exists()) {
        console.error(`DEBUG: Invite ${inviteId} does not exist.`);
        throw new functions.https.HttpsError("not-found", "Invite not found (pre-check).");
    }
    const val = snap.val();
    console.log(`DEBUG: Invite state before cancel:`, val);
    if (val.guestUid !== uid) {
        console.error(`DEBUG: Permission denied. Owner: ${val.guestUid}, Requester: ${uid}`);
    }
    const result = await inviteRef.transaction((current) => {
        if (!current) return;
        if (current.guestUid !== uid) return; // Not the guest
        if (current.status !== "pending") return; // Too late
        return { ...current, status: "cancelled", updatedAt: Date.now() };
    });
    if (!result.committed) {
        console.error("DEBUG: Transaction failed (not committed). Snapshot:", result.snapshot?.val());
        throw new functions.https.HttpsError("failed-precondition", "Cannot cancel (maybe accepted/rejected/deleted).");
    }
    console.log(`INVITE_CANCELLED: ${inviteId}`);
    return { success: true };
});
