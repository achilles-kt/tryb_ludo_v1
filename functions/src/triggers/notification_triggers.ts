import * as functions from "firebase-functions";
import { db, admin } from "../admin";

// ---------------------------------------------------------
// 1. On Message Created -> Send Notification
// ---------------------------------------------------------
export const onMessageCreated = functions.database
    .ref("messages/{convId}/{msgId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.val();
        const convId = context.params.convId;
        const senderId = message.senderId;

        if (!message || !senderId) return;

        console.log(`🔔 NOTIF: New message in ${convId} from ${senderId}`);

        // 1. Get Conversation Participants
        const convSnap = await db.ref(`conversations/${convId}/participants`).get();
        if (!convSnap.exists()) return;

        const participants = convSnap.val();
        const recipientUids = Object.keys(participants).filter(uid => uid !== senderId);

        if (recipientUids.length === 0) return;

        // 2. Get Sender Name (for Body)
        const senderSnap = await db.ref(`users/${senderId}/profile/displayName`).get();
        const senderName = senderSnap.val() || "Someone";

        const text = message.type === 'image' ? 'Sent an image' : message.text;

        // Check for gameId in payload or context
        const msgGameId = message.payload?.gameId || message.context?.gameId || "";

        // 3. Send to Each Recipient
        const payload: any = {
            notification: {
                title: senderName,
                body: text,
            },
            data: {
                type: "chat",
                convId: convId,
                senderId: senderId,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high" as const, // Fix for TypeScript enum/string type
                notification: {
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default"
                    }
                }
            }
        };

        if (msgGameId) {
            payload.data.gameId = msgGameId;
        }

        for (const uid of recipientUids) {
            const tokenSnap = await db.ref(`users/${uid}/fcmToken`).get();
            const token = tokenSnap.val();

            if (token) {
                try {
                    await admin.messaging().send({
                        token: token,
                        ...payload
                    });
                    console.log(`-> Sent FCM to ${uid}`);
                } catch (e) {
                    console.error(`-> Failed to send FCM to ${uid}`, e);
                }
            }
        }
    });

// ---------------------------------------------------------
// 2. On Friend Request -> Send Notification
// ---------------------------------------------------------
// Assuming structure: users/{uid}/friend_requests/{senderId} = true/timestamp
export const onFriendRequest = functions.database
    .ref("users/{uid}/friend_requests/{senderId}")
    .onCreate(async (snapshot, context) => {
        const targetUid = context.params.uid;
        const senderId = context.params.senderId;

        console.log(`🔔 NOTIF: Friend Request ${senderId} -> ${targetUid}`);

        // Get Sender Name
        const senderSnap = await db.ref(`users/${senderId}/profile/displayName`).get();
        const senderName = senderSnap.val() || "Someone";

        // Get Target Token
        const tokenSnap = await db.ref(`users/${targetUid}/fcmToken`).get();
        const token = tokenSnap.val();

        if (!token) return;

        try {
            await admin.messaging().send({
                token: token,
                notification: {
                    title: "New Friend Request",
                    body: `${senderName} wants to be friends!`,
                },
                data: {
                    type: "friend_request",
                    senderId: senderId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK"
                },
                android: {
                    priority: "high" as const,
                    notification: {
                        clickAction: "FLUTTER_NOTIFICATION_CLICK"
                    }
                }
            });
            console.log(`-> Sent Friend Req FCM to ${targetUid}`);
        } catch (e) {
            console.error(`-> Failed to send Friend Req FCM to ${targetUid}`, e);
        }
    });
