import * as functions from "firebase-functions";
import { db, admin } from "../admin";
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
// Helper: Send "User Joined" Notification
async function notifyContactJoined(targetUid: string, joinedUid: string) {
    // 1. Get Target Token
    const userSnap = await db.ref(`users/${targetUid}/fcmToken`).get();
    const token = userSnap.val();
    if (!token) return;

    // 2. Get Joined User Name
    const joinedSnap = await db.ref(`users/${joinedUid}/profile/displayName`).get();
    const joinedName = joinedSnap.val() || "A contact";

    // 3. Send Notification
    try {
        await admin.messaging().send({
            token: token,
            notification: {
                title: "New Friend on Tryb!",
                body: `${joinedName} has joined Tryb. Say hi!`,
            },
            data: {
                type: "contact_joined",
                peerId: joinedUid,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high" as const,
                notification: {
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default"
                    }
                }
            }
        });
        console.log(`-> Sent Contact Joined FCM to ${targetUid}`);
    } catch (e) {
        console.error(`-> Failed to send Contact Joined FCM to ${targetUid}`, e);
    }
}

// Helper: Create Mutual/One-Way connections
async function createContactMatches(uid: string, matchedUid: string, now: number): Promise<any> {
    const updates: any = {};

    // 1. Record directional link: A -> B
    updates[`contactsGraph/${uid}/${matchedUid}`] = true;

    // 2. Check if B -> A exists (Reciprocal check)
    const reciprocalSnap = await db.ref(`contactsGraph/${matchedUid}/${uid}`).get();
    const isMutual = reciprocalSnap.exists();

    if (isMutual) {
        // MUTUAL! Make Friends.
        updates[`friends/${uid}/${matchedUid}`] = {
            status: 'friend',
            updatedAt: now,
            source: 'contacts'
        };
        updates[`friends/${matchedUid}/${uid}`] = {
            status: 'friend',
            updatedAt: now,
            source: 'contacts'
        };

        // Remove from suggestions
        updates[`suggestedFriends/${uid}/${matchedUid}`] = null;
        updates[`suggestedFriends/${matchedUid}/${uid}`] = null;

    } else {
        // ONE-WAY! Create Suggestions.
        // A sees B (A is the one who synced/has the contact number)
        updates[`suggestedFriends/${uid}/${matchedUid}`] = {
            source: 'contacts',
            ts: now
        };
        // B sees A ("You might know A" - debatable, but usually good for growth)
        updates[`suggestedFriends/${matchedUid}/${uid}`] = {
            source: 'contacts',
            ts: now
        };
    }
    return updates;
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
    const now = Date.now();

    // We'll collect persistent updates first
    const persistentUpdates: any = {};
    persistentUpdates[`phoneIndex/${hash}`] = uid;
    persistentUpdates[`users/${uid}/profile/phoneHash`] = hash;

    // 4. REVERSE LOOKUP: Who has this hash in their contacts?
    // Check uploadedContacts/{hash}/{uploaderUid}
    const uploadedSnap = await db.ref(`uploadedContacts/${hash}`).get();

    // Check revers index
    if (uploadedSnap.exists()) {
        const uploaders = uploadedSnap.val(); // Map of {uid: true}
        console.log(`Register Phone: Found ${Object.keys(uploaders).length} users who know this number.`);

        for (const uploaderUid of Object.keys(uploaders)) {
            if (uploaderUid === uid) continue;

            // uploaderUid (A) has uid (B).
            const matchUpdates = await createContactMatches(uploaderUid, uid, now);
            Object.assign(persistentUpdates, matchUpdates);

            // 5. Send Notification to A (Old User)
            // Fire and forget notification to avoid slowing down response significantly
            notifyContactJoined(uploaderUid, uid).catch(e => console.error(e));
        }
    }

    await db.ref().update(persistentUpdates);

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

    if (hashes.length > 5000) {
        throw new functions.https.HttpsError("invalid-argument", "Too many contacts to sync at once.");
    }

    // A. Store these hashes for future lookup (Persistent Sync)
    // We write to `uploadedContacts/{hash}/{uid} = true`
    // This allows *new* users to find US if we have their number.
    const now = Date.now();
    const persistenceUpdates: any = {};

    // Using a loop here might generate a huge update object if 5000 contacts. 
    // RTDB update limit is ~1MB or so. 5000 paths might be too big for one atomic update.
    // But realistically hashes are short keys. 
    // Let's do it in chunks if needed, but for now we mix it with match logic below.

    // Note: Writing 1000s of `uploadedContacts` entries is heavy. 
    // We'll perform "Check & Write" in chunks.

    const matches: string[] = [];

    // Chunk process
    const CHUNK_SIZE = 50;

    // We will accumulate ALL updates (persistence + matches) to execute in batches or one go?
    // If we have 2000 contacts, one big update is risky.
    // Let's verify matches in chunks, but write persistence in parallel?

    // Optimization: Just check matches from `phoneIndex`. 
    // Write persistence in background? No, we need it done.

    // Let's iterate and build a big update object, but if it gets too big, we flush it?
    // Simplified approach: iterate chunks.

    const results: any[] = []; // Profiles to return

    for (let i = 0; i < hashes.length; i += CHUNK_SIZE) {
        const chunk = hashes.slice(i, i + CHUNK_SIZE);
        const chunkUpdates: any = {};

        const chunkPromises = chunk.map(async (h) => {
            if (typeof h !== 'string') return;

            // 1. Persistence Write Preparation
            // uploadedContacts/HASH/MY_UID = true
            chunkUpdates[`uploadedContacts/${h}/${uid}`] = true;

            // 2. Check Match in phoneIndex
            const snap = await db.ref(`phoneIndex/${h}`).get();
            if (snap.exists()) {
                const matchedUid = snap.val();
                if (matchedUid !== uid) {
                    matches.push(matchedUid);
                    // Generate match logic updates immediately?
                    // We can't do await creates inside map easily without Promise.all
                    // Let's just collect matchedUid and process after.
                }
            }
        });

        await Promise.all(chunkPromises);

        // Commit Persistence for this chunk immediately (to keep payload small)
        if (Object.keys(chunkUpdates).length > 0) {
            await db.ref().update(chunkUpdates);
        }
    }

    // Now process the matches found (usually small number, < 100)
    if (matches.length > 0) {
        const matchUpdates: any = {};

        for (const matchedUid of matches) {
            const up = await createContactMatches(uid, matchedUid, now);
            Object.assign(matchUpdates, up);

            // Fetch profile for UI
            const pSnap = await db.ref(`users/${matchedUid}/profile`).get();
            if (pSnap.exists()) {
                results.push({ ...pSnap.val(), uid: matchedUid });
            }
        }

        if (Object.keys(matchUpdates).length > 0) {
            await db.ref().update(matchUpdates);
        }
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
