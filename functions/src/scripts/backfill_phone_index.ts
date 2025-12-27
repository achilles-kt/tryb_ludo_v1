
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

// Initialize Admin SDK
// We can use the service account if running locally with checking env, 
// OR assume this is run via `firebase functions:shell` or local emulator.
// Best way for user: use the existing admin initialization if possible, or init with default creds.

// Since we are running this as a standalone script (node), we need credentials.
// However, the user is running `node lib/run_social_test.js` which likely has setup.
// Let's copy the setup style from `test_social.ts` or similar if it exists, or just specific logic.

// HARDCODED logic to match `contact_triggers.ts`
function hashPhone(phone: string): string {
    const clean = phone.replace(/\D/g, '');
    let target = clean;
    if (clean.length >= 10) {
        target = clean.substring(clean.length - 10);
    }
    return crypto.createHash("sha256").update(target).digest("hex");
}

async function backfill() {
    // If running in Cloud Functions environment or with GOOGLE_APPLICATION_CREDENTIALS, this works.
    if (admin.apps.length === 0) {
        admin.initializeApp();
    }

    const db = admin.database();
    console.log("Starting Phone Index Backfill...");

    const usersSnap = await db.ref('users').get();
    if (!usersSnap.exists()) {
        console.log("No users found.");
        process.exit(0);
    }

    const updates: any = {};
    let count = 0;

    usersSnap.forEach((child) => {
        const uid = child.key;
        const phone = child.child('phone/number').val();

        if (uid && phone && typeof phone === 'string') {
            const hash = hashPhone(phone);
            updates[`phoneIndex/${hash}`] = uid;

            // Also backfill the reference in profile if missing (optional but good)
            updates[`users/${uid}/profile/phoneHash`] = hash;

            console.log(`[${uid}] Phone: ${phone} -> Hash: ${hash.substring(0, 8)}...`);
            count++;
        }
    });

    if (count > 0) {
        await db.ref().update(updates);
        console.log(`Successfully backfilled ${count} users into phoneIndex!`);
    } else {
        console.log("No users with phone numbers found to backfill.");
    }
    process.exit(0);
}

backfill().catch(err => {
    console.error("Backfill failed:", err);
    process.exit(1);
});
