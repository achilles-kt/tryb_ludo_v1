import { onRequest } from "firebase-functions/v2/https";
import { startDMInternal, sendMessageInternal } from "./controllers/chat";
import { db } from "./admin";

export const verifyChatFlow = onRequest(async (req, res) => {
    const userA = "CHAT_TEST_USER_A";
    const userB = "CHAT_TEST_USER_B";
    const messageText = "Hello from automated test!";

    try {
        console.log("🧪 STARTING CHAT FLOW TEST");

        // 1. Start DM
        console.log(`STEP 1: Starting DM between ${userA} and ${userB}...`);
        const result = await startDMInternal(userA, userB);
        const convId = result.convId;

        if (!convId) throw new Error("Failed to create conversation");
        console.log(`✅ DM Created: ${convId}`);

        // 2. Send Message
        console.log(`STEP 2: User A sending message...`);
        const msgResult = await sendMessageInternal(userA, convId, messageText, "text");
        console.log(`✅ Message Sent: ${msgResult.msgId}`);

        // 3. Verify Data
        console.log(`STEP 3: Verifying DB state...`);
        const msgSnap = await db.ref(`messages/${convId}/${msgResult.msgId}`).get();
        const convSnap = await db.ref(`conversations/${convId}`).get();
        const inboxSnap = await db.ref(`user_conversations/${userB}/${convId}`).get();

        if (!msgSnap.exists()) throw new Error("Message not found in DB");
        if (msgSnap.val().text !== messageText) throw new Error("Message text mismatch");

        if (convSnap.val().lastMessage.text !== messageText) throw new Error("Last message mismatch");

        if (!inboxSnap.exists()) throw new Error("Inbox not updated for User B");

        res.json({
            success: true,
            message: "Chat Flow Verified Successfully",
            details: {
                convId,
                lastMessage: convSnap.val().lastMessage
            }
        });

    } catch (e: any) {
        console.error("Test Failed", e);
        res.status(500).json({
            success: false,
            error: e.message
        });
    }
});

// Deprecated schema check
// export const verifyChatSchema = ...
