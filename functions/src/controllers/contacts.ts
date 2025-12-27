import * as functions from "firebase-functions";
import { db } from "../admin";
import * as crypto from "crypto";

// Helper: Hash Phone consistently
function hashPhone(phone: string): string {
    // Normalize: remove all non-digits
    const clean = phone.replace(/\D/g, '');
    let target = clean;
    if (clean.length >= 10) {
        target = clean.substring(clean.length - 10);
    }
    return crypto.createHash("sha256").update(target).digest("hex");
}

// ---------------------------------------------------------
// 1. Register Phone (Privacy: Indexes Hash)
// ---------------------------------------------------------
export const registerPhone = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const phone = data.phone;
    if (!phone || typeof phone !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Phone number required.");
    }

    // 1. Hash it
    const hash = hashPhone(phone);

    // 2. Index it: phoneIndex/{hash} = uid
    // We strictly use set() to overwrite any old mapping
    await db.ref(`phoneIndex/${hash}`).set(uid);

    // 3. Store hash in profile for reference (optional, but good for "my hash")
    await db.ref(`users/${uid}/profile/phoneHash`).set(hash);

    console.log(`Registered phone hash for user ${uid}`);
    return { success: true };
});

// ---------------------------------------------------------
// 2. Sync Contacts (Bulk Lookup)
// ---------------------------------------------------------
export const syncContacts = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Login required.");
    }

    const hashes = data.hashes;
    if (!Array.isArray(hashes) || hashes.length === 0) {
        return { matches: [] };
    }

    // Limit batch size to prevent abuse? 
    // For now, allow 1000-2000.
    if (hashes.length > 5000) {
        throw new functions.https.HttpsError("invalid-argument", "Too many contacts to sync at once.");
    }

    // RTDB doesn't support "WHERE IN [...]".
    // We must fetch the needed nodes efficiently.
    // OPTION A: If phoneIndex is huge, fetching individual paths is slow (N reads).
    // OPTION B: If we assume client sends "all contacts", that's heavy.
    // REALITY: RTDB is fast. We can do parallel gets or use a specific structure.

    // Better strategy for RTDB:
    // We can't query multiple keys at once easily without downloading parent.
    // If `phoneIndex` grows to 1M users, we DO NOT want to download it all.
    // We have to iterate list and `db.ref('phoneIndex/' + hash).get()`.
    // We can run these in parallel promises with concurrency limit.

    const matches: string[] = [];
    const promises: Promise<void>[] = [];

    // Simple chunking to avoid choking Cloud Functions
    const CHUNK_SIZE = 50;

    for (let i = 0; i < hashes.length; i += CHUNK_SIZE) {
        const chunk = hashes.slice(i, i + CHUNK_SIZE);
        const chunkPromises = chunk.map(async (h) => {
            if (typeof h !== 'string') return;
            const snap = await db.ref(`phoneIndex/${h}`).get();
            if (snap.exists()) {
                const matchedUid = snap.val();
                if (matchedUid !== uid) { // Don't match self
                    matches.push(matchedUid);
                }
            }
        });
        await Promise.all(chunkPromises);
    }

    if (matches.length === 0) {
        return { matches: [] };
    }

    // Process Graph Logic
    const updates: any = {};
    const results: any[] = [];
    const now = Date.now();

    // We need to check reciprocal links for ALL matches found.
    // "Does B know A?" -> Check `contactsGraph/B/A`

    // We can fetch `contactsGraph` for each match or optimize.
    // Optimization: We know A just found B. So we set `contactsGraph/A/B = true`.
    // We check `contactsGraph/B/A`.

    for (const matchedUid of matches) {
        // 1. Record directional link: A -> B
        updates[`contactsGraph/${uid}/${matchedUid}`] = true;

        // 2. Check if B -> A exists
        const reciprocalSnap = await db.ref(`contactsGraph/${matchedUid}/${uid}`).get();
        const isMutual = reciprocalSnap.exists();

        if (isMutual) {
            // MUTUAL! Make Friends.
            // A -> B
            updates[`friends/${uid}/${matchedUid}`] = {
                status: 'friend',
                updatedAt: now,
                source: 'contacts'
            };
            // B -> A
            updates[`friends/${matchedUid}/${uid}`] = {
                status: 'friend',
                updatedAt: now,
                source: 'contacts'
            };

            // Remove from suggestions (if any)
            updates[`suggestedFriends/${uid}/${matchedUid}`] = null;
            updates[`suggestedFriends/${matchedUid}/${uid}`] = null;

        } else {
            // ONE-WAY! Create Suggestions.
            // A sees B
            updates[`suggestedFriends/${uid}/${matchedUid}`] = {
                source: 'contacts',
                ts: now
            };
            // B sees A ("You might know A")
            updates[`suggestedFriends/${matchedUid}/${uid}`] = {
                source: 'contacts',
                ts: now
            };
        }

        // Fetch profile for return (optional, mostly for UI feedback)
        const pSnap = await db.ref(`users/${matchedUid}/profile`).get();
        if (pSnap.exists()) {
            results.push({ ...pSnap.val(), uid: matchedUid });
        }
    }

    if (Object.keys(updates).length > 0) {
        await db.ref().update(updates);
    }

    console.log(`Sync Contacts: Processed ${matches.length} matches for User ${uid}`);
    return { matches: results };
});

// ---------------------------------------------
// 3. Admin Backfill Tool (Temp)
// ---------------------------------------------
export const backfillPhones = functions.https.onRequest(async (req, res) => {
    // Basic security: check for a secret query param if needed, or leave open for dev
    // For now, explicit simple run.
    console.log("Creating Phone Index Backfill...");
    const usersSnap = await db.ref('users').get();
    if (!usersSnap.exists()) {
        res.send("No users found.");
        return;
    }

    const updates: any = {};
    let count = 0;

    const results: string[] = [];

    usersSnap.forEach((child) => {
        const uid = child.key;
        const phone = child.child('phone/number').val(); // Should use 'number' not 'phone/number' based on structure? logic: child('phone').child('number')
        // Actually structure is users/{uid}/phone/number based on trigger.
        // in loops: child.val().phone?.number or child.child('phone/number').val()

        const pVal = child.val().phone;
        const number = pVal ? pVal.number : null;

        if (uid && number && typeof number === 'string') {
            const hash = hashPhone(number);
            updates[`phoneIndex/${hash}`] = uid;
            updates[`users/${uid}/profile/phoneHash`] = hash;
            count++;
            results.push(`User: ${uid} | Raw: ${number} | Hash: ${hash}`);
        }
    });

    if (count > 0) {
        await db.ref().update(updates);
    }

    res.send(`Processed ${count} Users:\n` + results.join('\n'));
});
