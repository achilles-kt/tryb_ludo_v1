import * as functions from "firebase-functions";
import { db } from "../admin";
import * as crypto from "crypto";

function hashPhone(phone: string): string {
    // Normalize: remove all non-digits
    const clean = phone.replace(/\D/g, '');
    // If < 10 digits, probably invalid, but we hash what we get to match client logic.
    // Client logic in ContactService uses last 10 digits.
    // To match consistently, let's say we hash the *last 10 digits* if length >= 10.

    let target = clean;
    if (clean.length >= 10) {
        target = clean.substring(clean.length - 10);
    }

    return crypto.createHash("sha256").update(target).digest("hex");
}

export const maintainPhoneIndex = functions.database
    .ref("users/{uid}/phone")
    .onWrite(async (change, context) => {
        const uid = context.params.uid;
        const before = change.before.exists() ? change.before.val() : null;
        const after = change.after.exists() ? change.after.val() : null;

        const beforePhone = before ? (before.number as string) : null;
        const afterPhone = after ? (after.number as string) : null;

        // 1. If phone didn't change, exit
        if (beforePhone === afterPhone) return null;

        const updates: any = {};

        // 2. If old phone existed, remove from index
        if (beforePhone) {
            const oldHash = hashPhone(beforePhone);
            // Only remove if it points to US. 
            // In a real app, verify we are removing OUR entry, but for now safe to remove
            // Actually, concurrency issue: if someone else has same phone (collision?), we might delete their index.
            // But phone numbers should be unique per user usually. 
            // Better: Check if index points to us before delete.
            const oldRef = db.ref(`phoneIndex/${oldHash}`);
            const oldSnap = await oldRef.get();
            if (oldSnap.exists() && oldSnap.val() === uid) {
                updates[`phoneIndex/${oldHash}`] = null;
            }
        }

        // 3. If new phone exists, add to index
        if (afterPhone) {
            const newHash = hashPhone(afterPhone);
            updates[`phoneIndex/${newHash}`] = uid;
        }

        if (Object.keys(updates).length > 0) {
            await db.ref().update(updates);
            console.log(`Updated phone index for User ${uid}`);
        }

        return null;
    });
