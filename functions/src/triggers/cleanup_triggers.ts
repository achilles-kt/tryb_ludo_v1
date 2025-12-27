import * as functions from 'firebase-functions';
import { db } from '../admin';

// Run daily at midnight
export const dailyMessageCleanup = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
    const NOW = Date.now();
    const CUTOFF = NOW - (30 * 24 * 60 * 60 * 1000); // 30 Days ago
    console.log(`🧹 Starting Daily Cleanup. Cutoff: ${new Date(CUTOFF).toISOString()}`);

    const messagesRef = db.ref('messages');

    // We can't query all messages at once efficiently in RTDB if strictly nested.
    // Structure: messages/{convId}/{msgId}
    // We need to iterate conversations.
    // Optimization: Depending on scale, this might timeout. 
    // For MVP/Start, iterating top-level conversations is okay.

    const convSnap = await messagesRef.once('value');
    if (!convSnap.exists()) return;

    const updates: any = {};
    let deleteCount = 0;

    convSnap.forEach((conv) => {
        const convId = conv.key;
        if (!convId) return;

        conv.forEach((msg) => {
            const msgData = msg.val();
            // Check 'ts' or 'timestamp'
            const ts = msgData.ts || msgData.timestamp;

            if (ts && ts < CUTOFF) {
                updates[`messages/${convId}/${msg.key}`] = null;
                deleteCount++;
            }
        });
    });

    if (deleteCount > 0) {
        await db.ref().update(updates);
        console.log(`✨ Deleted ${deleteCount} old messages.`);
    } else {
        console.log("✅ No messages to clean up.");
    }
});
