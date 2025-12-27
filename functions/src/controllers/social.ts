import * as functions from "firebase-functions";
import { db } from "../admin";

// ---------------------------------------------------------
// 1. Send Friend Request
// ---------------------------------------------------------
export const sendFriendRequest = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const targetUid = data.targetUid;
    if (!targetUid || typeof targetUid !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Target UID required.");
    }

    if (uid === targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "Cannot add yourself.");
    }

    // Check if target exists (optional validity check)
    const targetSnap = await db.ref(`users/${targetUid}/profile`).get();
    if (!targetSnap.exists()) {
        throw new functions.https.HttpsError("not-found", "User not found.");
    }

    // Check existing relationship
    const myRef = db.ref(`friends/${uid}/${targetUid}`);
    const otherRef = db.ref(`friends/${targetUid}/${uid}`);

    const mySnap = await myRef.get();
    if (mySnap.exists()) {
        const status = mySnap.val().status;
        if (status === "friend") {
            throw new functions.https.HttpsError("already-exists", "Already friends.");
        }
        if (status === "requested") {
            throw new functions.https.HttpsError("already-exists", "Request already sent.");
        }
        if (status === "pending") {
            throw new functions.https.HttpsError("failed-precondition", "You have a pending request from this user. Accept it instead.");
        }
    }

    const now = Date.now();

    // updates
    const updates: any = {};
    updates[`friends/${uid}/${targetUid}`] = {
        status: "requested",
        createdAt: now,
        source: "manual"
    };
    updates[`friends/${targetUid}/${uid}`] = {
        status: "pending",
        createdAt: now,
        source: "manual"
    };

    await db.ref().update(updates);

    console.log(`Friend request sent: ${uid} -> ${targetUid}`);
    return { success: true };
});

// ---------------------------------------------------------
// 2. Respond to Friend Request
// ---------------------------------------------------------
export const respondToFriendRequest = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const targetUid = data.targetUid;
    const action = data.action; // 'accept' | 'reject'

    if (!targetUid || !action) {
        throw new functions.https.HttpsError("invalid-argument", "Missing arguments.");
    }

    if (action !== "accept" && action !== "reject") {
        throw new functions.https.HttpsError("invalid-argument", "Invalid action.");
    }

    // Verify 'pending' status
    const myRef = db.ref(`friends/${uid}/${targetUid}`);
    const snap = await myRef.get();

    if (!snap.exists() || snap.val().status !== "pending") {
        throw new functions.https.HttpsError("failed-precondition", "No pending request from this user.");
    }

    const updates: any = {};
    const now = Date.now();

    if (action === "accept") {
        updates[`friends/${uid}/${targetUid}`] = {
            status: "friend",
            updatedAt: now,
            source: snap.val().source // keep original source
        };
        updates[`friends/${targetUid}/${uid}`] = {
            status: "friend",
            updatedAt: now,
            source: snap.val().source
        };
        console.log(`Friend request accepted: ${uid} <-> ${targetUid}`);
    } else {
        // Reject - remove both
        updates[`friends/${uid}/${targetUid}`] = null;
        updates[`friends/${targetUid}/${uid}`] = null;
        console.log(`Friend request rejected: ${uid} -x- ${targetUid}`);
    }

    await db.ref().update(updates);
    return { success: true, action };
});

// ---------------------------------------------------------
// 3. Remove Friend
// ---------------------------------------------------------
export const removeFriend = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const targetUid = data.targetUid;
    if (!targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "Target UID required.");
    }

    // Just strictly remove both paths
    const updates: any = {};
    updates[`friends/${uid}/${targetUid}`] = null;
    updates[`friends/${targetUid}/${uid}`] = null;

    await db.ref().update(updates);
    console.log(`Friend removed: ${uid} -x- ${targetUid}`);
    return { success: true };
});
