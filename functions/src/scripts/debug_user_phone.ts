
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

// Replicate logic EXACTLY
function hashPhone(phone: string): string {
    const clean = phone.replace(/\D/g, '');
    let target = clean;
    if (clean.length >= 10) {
        target = clean.substring(clean.length - 10);
    }
    return crypto.createHash("sha256").update(target).digest("hex");
}

async function debugUser(uid: string) {
    if (admin.apps.length === 0) {
        // Try default init, might fail if no creds in env
        admin.initializeApp({
            databaseURL: "https://tryb-ludo-v1-default-rtdb.firebaseio.com"
        });
    }

    const db = admin.database();
    console.log(`Debugging User: ${uid}`);

    const userSnap = await db.ref(`users/${uid}`).get();
    if (!userSnap.exists()) {
        console.log("User NOT found in DB.");
        return;
    }

    const phoneData = userSnap.child('phone').val();
    console.log("User Phone Data:", phoneData);

    if (!phoneData || !phoneData.number) {
        console.log("No phone number registered!");
        return;
    }

    const rawNumber = phoneData.number;
    const computedHash = hashPhone(rawNumber);
    console.log(`Raw Number: ${rawNumber}`);
    console.log(`Computed Hash: ${computedHash}`);

    const indexSnap = await db.ref(`phoneIndex/${computedHash}`).get();
    if (indexSnap.exists()) {
        console.log(`✅ Index MATCH found! Points to: ${indexSnap.val()}`);
    } else {
        console.log(`❌ Index MISSING for this hash!`);
    }

    process.exit(0);
}

// User ID provided by user
const targetUid = "3yVkYT4V62SFP9wYRDHFS4mmPSD2";

debugUser(targetUid).catch(console.error);
