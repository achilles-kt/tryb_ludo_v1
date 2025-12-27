
import * as admin from 'firebase-admin';
import { sendMessageInternal } from '../controllers/chat';

async function inject() {
    if (admin.apps.length === 0) {
        admin.initializeApp({
            databaseURL: "https://tryb-ludo-v1-default-rtdb.firebaseio.com"
        });
    }

    const db = admin.database();

    // 1. Get Two Users
    const usersSnap = await db.ref('users').limitToFirst(2).get();
    if (usersSnap.numChildren() < 2) {
        console.error("Not enough users.");
        process.exit(1);
    }

    const uids = Object.keys(usersSnap.val());
    const uid1 = uids[0];
    const uid2 = uids[1];

    console.log(`Injecting Activity between ${uid1} and ${uid2}`);

    // 2. Determine Conv ID
    const convId = uid1 < uid2 ? `dm_${uid1}_${uid2}` : `dm_${uid2}_${uid1}`;

    // 3. Ensure Conversation Exists (Mock Participants)
    await db.ref(`conversations/${convId}`).update({
        participants: {
            [uid1]: true,
            [uid2]: true
        },
        type: 'dm',
        updatedAt: Date.now()
    });

    // 4. Send Game Result
    try {
        const res = await sendMessageInternal(
            uid1, // Sender
            convId,
            null, // No Text
            'game_result', // Type
            {
                winner: "Tryb Legend",
                score: "2 - 1",
                mode: "2v2 Team Up"
            },
            {
                gameId: "mock_game_123"
            }
        );
        console.log("✅ Success! Message ID:", res.msgId);
    } catch (e) {
        console.error("❌ Error:", e);
    }

    process.exit(0);
}

inject().catch(console.error);
