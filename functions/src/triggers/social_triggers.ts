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
        const readPromises: Promise<void>[] = [];

        // Create pairs for everyone
        for (let i = 0; i < humanIds.length; i++) {
            for (let j = i + 1; j < humanIds.length; j++) {
                const u1 = humanIds[i];
                const u2 = humanIds[j];

                // 1. Always update Recently Played (History)
                updates[`recentlyPlayed/${u1}/${u2}`] = {
                    gameId,
                    lastPlayedAt: now,
                    mode
                };
                updates[`recentlyPlayed/${u2}/${u1}`] = {
                    gameId,
                    lastPlayedAt: now,
                    mode
                };

                // 2. Check Friendship for Suggestions
                readPromises.push((async () => {
                    const fSnap = await db.ref(`friends/${u1}/${u2}/status`).get();
                    const status = fSnap.exists() ? fSnap.val() : null;

                    // If NOT friend and NOT pending/requested, add to suggested
                    if (status !== 'friend' && status !== 'pending' && status !== 'requested') {
                        // Add reciprocal suggestions
                        updates[`suggestedFriends/${u1}/${u2}`] = {
                            source: 'recent_game',
                            ts: now,
                            gameId
                        };
                        updates[`suggestedFriends/${u2}/${u1}`] = {
                            source: 'recent_game',
                            ts: now,
                            gameId
                        };
                    }
                })());
            }
        }

        await Promise.all(readPromises);

        if (Object.keys(updates).length > 0) {
            await db.ref().update(updates);
            console.log(`Updated social lists (Recent + Suggested) for ${humanIds.length} players.`);
        }

        return null;
    });

// ---------------------------------------------------------
// 2. [REMOVED] Notify on Friend Request 
// (Moved to notification_triggers.onFriendRelationshipUpdate)
// ---------------------------------------------------------
