const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://tryb-ludo-v1-default-rtdb.firebaseio.com"
    });
}

const db = admin.database();

async function testSyncLogic() {
    console.log("--- Testing syncContacts Logic ---");

    // 1. Define the hash we saw in the user's DB
    // phoneIndex has: 4226a656a35704f2a2618cf07e660a6fba38af0440a785cb1d4a047d0a3b9f15 -> TEST_USER_A
    const targetHash = "4226a656a35704f2a2618cf07e660a6fba38af0440a785cb1d4a047d0a3b9f15";

    // This simulates the array of hashes sent by the client
    const inputHashes = [
        "some_random_hash_that_wont_match",
        targetHash,
        "another_random_hash"
    ];

    console.log(`Input: ${inputHashes.length} hashes.`);
    console.log(`Target: ${targetHash}`);

    const matches = [];

    // Logic from functions/src/controllers/contacts.ts
    for (const h of inputHashes) {
        const snap = await db.ref(`phoneIndex/${h}`).get();
        if (snap.exists()) {
            const matchedUid = snap.val();
            console.log(`✅ MATCH: Hash ${h.substring(0, 10)}... -> UID: ${matchedUid}`);
            matches.push(matchedUid);
        } else {
            console.log(`❌ NO MATCH: Hash ${h.substring(0, 10)}...`);
        }
    }

    console.log("--- Result ---");
    console.log("Matches found:", matches);

    if (matches.includes("TEST_USER_A")) {
        console.log("🎉 SUCCESS: Logic found TEST_USER_A correctly.");
    } else {
        console.log("⚠️ FAILURE: Logic missed the existing index entry.");
    }

    process.exit(0);
}

testSyncLogic();
