import { onRequest } from "firebase-functions/v2/https";
import { db } from "./admin";
import * as crypto from "crypto";

// Helper to match the controller logic
function hashPhone(phone: string): string {
    return crypto.createHash("sha256").update(phone).digest("hex");
}

export const verifyContactFlow = onRequest(async (req, res) => {
    // 1. Setup Test Data
    const userA = "TEST_USER_A"; // The one being "found"
    const userB = "TEST_USER_B"; // The one "searching"
    const phoneA = "+919999999999";
    const hashA = hashPhone(phoneA);

    console.log("🧪 STARTING CONTACT FLOW TEST");

    // Clear old data
    await db.ref(`phoneIndex/${hashA}`).remove();
    await db.ref(`users/${userA}/profile`).update({ displayName: "Found User A", avatarUrl: "test_avatar" });

    // 2. Simulate Register Phone (User A)
    console.log(`STEP 1: Registering phone for ${userA}...`);
    // Direct DB write to simulate internal logic of registerPhone
    await db.ref(`phoneIndex/${hashA}`).set(userA);

    // 3. Simulate Sync Contacts (User B)
    console.log(`STEP 2: Syncing contacts for ${userB}...`);
    // We simulate client sending hashA
    const hashes = [hashA, "some_random_hash"];

    // Simulate lookup logic
    const matches: any[] = [];
    for (const h of hashes) {
        const snap = await db.ref(`phoneIndex/${h}`).get();
        if (snap.exists()) {
            const uid = snap.val();
            // Fetch profile
            const pSnap = await db.ref(`users/${uid}/profile`).get();
            const p = pSnap.val();
            matches.push({ uid, name: p.displayName });
        }
    }

    // 4. Verify
    const match = matches.find(m => m.uid === userA);
    if (!match) {
        console.error("Match not found!", matches);
        res.status(500).json({ success: false, message: "Match not found" });
        return;
    }

    if (match.name !== "Found User A") {
        console.error("Profile mismatch!", match);
        res.status(500).json({ success: false, message: "Profile mismatch" });
        return;
    }

    console.log("✅ Contact Flow Test Passed");
    res.json({
        success: true,
        message: "Contact Flow Test Passed. User A found via phone hash.",
        match: match
    });
});
