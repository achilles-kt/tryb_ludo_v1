import * as functions from "firebase-functions";
import { db } from "../admin";

// ---------------------------------------------------------
// Helper: Deterministic DM ID
// ---------------------------------------------------------
// Ensures we don't create duplicate DMs between two users.
// ID format: dm_{minUid}_{maxUid}
export function getDmId(uid1: string, uid2: string): string {
    return uid1 < uid2 ? `dm_${uid1}_${uid2}` : `dm_${uid2}_${uid1}`;
}

// ---------------------------------------------------------
// 1. Start DM (Create Conversation)
// ---------------------------------------------------------
export const startDM = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const targetUid = data.targetUid;
    if (!targetUid || typeof targetUid !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Target UID required.");
    }

    if (uid === targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "Cannot DM yourself.");
    }

    return await startDMInternal(uid, targetUid);
});

export async function startDMInternal(uid: string, targetUid: string) {
    // 1. Check/Create Conversation
    const convId = getDmId(uid, targetUid);
    const convRef = db.ref(`conversations/${convId}`);

    // We use a transaction or simple check? 
    // Since ID is deterministic, we can just "ensure" it exists.
    // If it exists, we just return the ID.
    // If not, we create it.

    const snap = await convRef.get();
    const now = Date.now();

    if (!snap.exists()) {
        const participants: any = {};
        participants[uid] = true;
        participants[targetUid] = true;

        await convRef.set({
            type: "dm",
            participants,
            createdAt: now,
            updatedAt: now
        });
    }

    // 2. Update User Inboxes (Force to top / Visible)
    const inboxUpdate: any = {};

    // For Me
    inboxUpdate[`user_conversations/${uid}/${convId}`] = {
        seen: true, // I initiated it
        updatedAt: now
    };

    // For Them
    // We might NOT show it in their list until a message is sent?
    // Or we show it immediately? 
    // Standard practice: Show empty chat? Or wait for first message?
    // Let's Add validation: typically a "Start DM" intent implies we are about to message.
    // Let's add it to both so it's ready.
    inboxUpdate[`user_conversations/${targetUid}/${convId}`] = {
        seen: false,
        updatedAt: now
    };

    await db.ref().update(inboxUpdate);

    return { success: true, convId };
}

// ---------------------------------------------------------
// 1b. Start Group Conversation
// ---------------------------------------------------------
export const startGroupConversation = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const participants = data.participants; // Array of UIDs
    if (!participants || !Array.isArray(participants) || participants.length < 2) {
        throw new functions.https.HttpsError("invalid-argument", "At least 2 participants required.");
    }

    // Sort to be deterministic
    const sorted = [...participants].sort();
    const convId = `gp_${sorted.join('_')}`;

    const convRef = db.ref(`conversations/${convId}`);
    const snap = await convRef.get();
    const now = Date.now();

    if (!snap.exists()) {
        const pMap: any = {};
        for (const p of sorted) {
            pMap[p] = true;
        }

        await convRef.set({
            type: "group",
            participants: pMap,
            createdAt: now,
            updatedAt: now
        });
    }

    // Force Inboxes
    const updates: any = {};
    for (const p of sorted) {
        updates[`user_conversations/${p}/${convId}`] = {
            seen: (p === uid), // Seen for creator?
            updatedAt: now
        };
    }
    await db.ref().update(updates);

    return { success: true, convId };
});

// ---------------------------------------------------------
// 2. Send Message
// ---------------------------------------------------------
// ---------------------------------------------------------
// 2. Send Message / Activity
// ---------------------------------------------------------
export const sendMessage = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const convId = data.convId;
    const text = data.text; // Optional for non-text events
    const type = data.type || "text";
    const payload = data.payload || {}; // Rich data (game results, transfers)
    const msgContext = data.context || {}; // Source context (game_id, mode)

    if (!convId) {
        throw new functions.https.HttpsError("invalid-argument", "convId required.");
    }
    // Text required only if type is text
    if (type === 'text' && !text) {
        throw new functions.https.HttpsError("invalid-argument", "text required for text messages.");
    }

    return await sendMessageInternal(uid, convId, text, type, payload, msgContext);
});

export async function sendMessageInternal(
    uid: string,
    convId: string,
    text: string | null,
    type: string,
    payload: any = {},
    msgContext: any = {}
) {
    // 1. Validate Participation
    const convRef = db.ref(`conversations/${convId}`);
    const convSnap = await convRef.get();

    if (!convSnap.exists()) {
        throw new functions.https.HttpsError("not-found", "Conversation not found.");
    }

    const conv = convSnap.val();
    if (!conv.participants || !conv.participants[uid]) {
        // Allow SYSTEM to write? For now assume caller must be participant.
        // If we want Game End triggers to write as system, we need a bypass.
        // uid "SYSTEM" or similar.
        if (uid !== 'system') { // Reserve 'system' for internal calls
            throw new functions.https.HttpsError("permission-denied", "You are not a participant.");
        }
    }

    const now = Date.now();

    // 2. Create Message / Activity Item
    const msgRef = db.ref(`messages/${convId}`).push();
    const msgId = msgRef.key!;

    const message: any = {
        senderId: uid,
        type,
        ts: now,
        payload,
        context: msgContext
    };

    if (text) {
        message.text = text.toString().substring(0, 1000);
    }

    // 3. Update Conversation & Inboxes (Fan-out)
    const updates: any = {};

    // A. The Message
    updates[`messages/${convId}/${msgId}`] = message;

    // B. Conversation Last Message
    updates[`conversations/${convId}/lastMessage`] = message;
    updates[`conversations/${convId}/updatedAt`] = now;

    // C. Generate Snippet
    let snippetText = "New Activity";
    if (type === 'text') snippetText = text ? text.substring(0, 50) : 'Message';
    else if (type === 'game_invite') snippetText = "🎮 Game Invite";
    else if (type === 'game_result') snippetText = "🏆 Game Result";
    else if (type === 'transfer') snippetText = "💰 Transfer";
    else if (type === 'image') snippetText = "📷 Image";

    // D. User Inboxes
    const participantIds = Object.keys(conv.participants);
    for (const pUid of participantIds) {
        updates[`user_conversations/${pUid}/${convId}/seen`] = (pUid === uid);
        updates[`user_conversations/${pUid}/${convId}/updatedAt`] = now;

        updates[`user_conversations/${pUid}/${convId}/snippet`] = {
            text: snippetText,
            senderId: uid,
            ts: now,
            type: type
        };
    }

    await db.ref().update(updates);

    await db.ref().update(updates);

    // 4. Send High Priority Notification (Fire & Forget)
    // REMOVED: Managed by notification_triggers.ts (onMessageCreated)
    // This avoids duplicates and uses V1 API.

    return { success: true, msgId };

    return { success: true, msgId };
}
