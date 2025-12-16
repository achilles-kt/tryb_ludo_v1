import * as functions from "firebase-functions";
import { db, admin } from "../admin";

// ---------------------------------------------
// Trigger: On Invite Created -> Send PN to Host
// ---------------------------------------------
export const onInviteCreated = functions.database
    .ref("invites/{inviteId}")
    .onCreate(async (snapshot, context) => {
        const invite = snapshot.val();
        const inviteId = context.params.inviteId;
        const hostUid = invite.hostUid;
        const guestUid = invite.guestUid;

        console.log(`INVITE_TRIGGER: New invite ${inviteId} for ${hostUid} from ${guestUid}`);

        // 1. Get Host Token
        const userSnap = await db.ref(`users/${hostUid}/fcmToken`).get();
        const token = userSnap.val();

        if (!token) {
            console.log(`INVITE_TRIGGER: No FCM token for host ${hostUid}, skipping.`);
            return;
        }

        // 2. Get Guest Name
        const guestSnap = await db.ref(`users/${guestUid}/profile/displayName`).get();
        const guestName = guestSnap.val() || "A Friend";

        // 3. Send Notification
        const title = "Game Invite!";
        const body = `${guestName} wants to play Ludo with you!`;

        try {
            await admin.messaging().send({
                token: token,
                notification: {
                    title,
                    body,
                },
                data: {
                    type: "robust_invite", // Distinct type from previous system
                    inviteId: inviteId,
                    hostUid: hostUid,
                    guestUid: guestUid,
                    click_action: "FLUTTER_NOTIFICATION_CLICK"
                },
                android: {
                    priority: "high",
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default"
                        }
                    }
                }
            });
            console.log(`INVITE_TRIGGER: Notification sent to ${hostUid}`);
        } catch (e) {
            console.error("INVITE_TRIGGER: FCM Error", e);
        }
    });
