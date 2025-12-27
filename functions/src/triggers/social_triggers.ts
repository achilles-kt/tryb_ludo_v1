import * as functions from "firebase-functions";
import { db } from "../admin";

// ---------------------------------------------------------
// 1. Update Recent Players on Game Complete
// ---------------------------------------------------------
export const updateRecentPlayers = functions.database
    .ref("games/{gameId}/state")
    .onUpdate(async (change, context) => {
        const state = change.after.val();
        if (state !== "completed") {
            console.log(`[RecentPlayers] State change ignored: ${state}`);
            return null;
        }

        const gameId = context.params.gameId;
        console.log(`[RecentPlayers] Game ${gameId} completed. Fetching details...`);

        // Fetch full game data
        const gameSnap = await db.ref(`games/${gameId}`).get();
        if (!gameSnap.exists()) {
            console.log(`[RecentPlayers] Game ${gameId} snapshot missing.`);
            return null;
        }
        const game = gameSnap.val();

        if (!game.board) {
            console.log(`[RecentPlayers] Game ${gameId} has no board.`);
            return null;
        }

        const playerIds = Object.keys(game.board);
        // exclude 'BOT_PLAYER'
        const humanIds = playerIds.filter(id => id !== "BOT_PLAYER");

        console.log(`[RecentPlayers] Human IDs found: ${JSON.stringify(humanIds)}`);

        if (humanIds.length < 2) {
            console.log(`[RecentPlayers] Not enough humans (<2) to pair.`);
            return null; // No pairs to make
        }

        const now = Date.now();
        const updates: any = {};
        const mode = game.mode || "2p";

        // Create pairs for everyone
        for (let i = 0; i < humanIds.length; i++) {
            for (let j = i + 1; j < humanIds.length; j++) {
                const u1 = humanIds[i];
                const u2 = humanIds[j];

                // Update for U1
                updates[`recentlyPlayed/${u1}/${u2}`] = {
                    gameId,
                    lastPlayedAt: now,
                    mode
                };

                // Update for U2
                updates[`recentlyPlayed/${u2}/${u1}`] = {
                    gameId,
                    lastPlayedAt: now,
                    mode
                };
            }
        }

        if (Object.keys(updates).length > 0) {
            await db.ref().update(updates);
            console.log(`Updated recentlyPlayed for ${humanIds.length} players.`);
        }

        return null;
    });

// ---------------------------------------------------------
// 2. Notify on Friend Request
// ---------------------------------------------------------
export const notifyFriendRequest = functions.database
    .ref("friends/{uid}/{friendUid}")
    .onWrite(async (change, context) => {
        const after = change.after.val();
        const before = change.before.val();

        // 1. Only care if status CHANGED to 'pending' (Request Received)
        if (!after || after.status !== "pending") {
            return null;
        }
        if (before && before.status === "pending") {
            return null; // Already notified
        }

        const receiverUid = context.params.uid;
        const senderUid = context.params.friendUid;

        console.log(`[FriendRequest] Notification: ${senderUid} -> ${receiverUid}`);

        // 2. Fetch Sender Profile
        const senderSnap = await db.ref(`users/${senderUid}/profile`).get();
        if (!senderSnap.exists()) {
            console.log(`[FriendRequest] Sender profile missing.`);
            return null;
        }
        const sender = senderSnap.val();
        const senderName = sender.displayName || "Someone";

        // 3. Fetch Receiver Tokens
        const tokensSnap = await db.ref(`users/${receiverUid}/fcmTokens`).get();
        if (!tokensSnap.exists()) {
            console.log(`[FriendRequest] No tokens for user ${receiverUid}.`);
            return null;
        }
        const tokens = Object.keys(tokensSnap.val());

        // 4. Send Notification
        const payload = {
            notification: {
                title: "New Friend Request",
                body: `${senderName} sent you a friend request!`,
            },
            data: {
                type: "friend_request",
                senderUid: senderUid
            }
        };

        const admin = await import("firebase-admin"); // Dynamic import or ensured import
        await admin.messaging().sendToDevice(tokens, payload);
        console.log(`[FriendRequest] Sent to ${tokens.length} devices.`);

        return null;
    });
