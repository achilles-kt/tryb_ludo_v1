import { db, admin } from "./admin";

// ---------------------------------------------
// Wallet Utility
// ---------------------------------------------
export async function applyWalletDelta(
    uid: string,
    delta: number,
    type: string,
    opts: {
        currency?: 'gold' | 'gems';
        gameId?: string | null;
        tableId?: string | null;
        meta?: any;
    } = {}
) {
    const currency = opts.currency || 'gold'; // Default to gold
    const walletRef = db.ref(`users/${uid}/wallet`);

    const result = await walletRef.transaction((current: any) => {
        if (current === null) {
            // Essential: Return null to imply "no change/delete" if data is missing.
            // If data actually exists on server, this mismatch forces a retry with real data.
            // If we defaulted to 0 and aborted, we would never see the real data.
            return null;
        }

        const before = Number(current[currency] || 0);
        const after = before + delta;

        console.log(`TRX_ATTEMPT: ${uid} | CurrentVal: ${JSON.stringify(current)} | Before: ${before} | After: ${after}`);

        if (after < 0) {
            console.warn(`TRX_FAIL: Insufficient Funds for ${uid}. Has ${before}, needs ${Math.abs(delta)}`);
            return; // Abort
        }

        return {
            ...current,
            [currency]: after,
            updatedAt: Date.now(),
        };
    });

    if (!result.committed) {
        // If we aborted (returned undefined), committed is false.
        // If we returned null (and it was accepted because data didn't exist), committed is true but snapshot is null.
        // We essentially treat "no start data" as insufficient funds too (since user should have wallet).
        throw new Error("INSUFFICIENT_FUNDS");
    }

    const currentVal = result.snapshot.val() || {};
    const finalBalance = Number(currentVal[currency] || 0);
    const initialBalance = finalBalance - delta;

    const txnRef = db.ref(`walletTransactions/${uid}`).push();
    await txnRef.set({
        amount: delta,
        currency,
        type,
        gameId: opts.gameId ?? null,
        tableId: opts.tableId ?? null,
        beforeBalance: initialBalance,
        afterBalance: finalBalance,
        createdAt: Date.now(),
        meta: opts.meta ?? null,
    });

    console.log(`💰 Wallet ${currency} updated for ${uid}: ${initialBalance} → ${finalBalance}`);
}

// ---------------------------------------------
// Helper: Send Poke Notification (FCM)
// ---------------------------------------------
export async function sendPokeNotification(targetUid: string, pokerUid: string, reason: string) {
    // 1. Get Target FCM Token
    const userSnap = await db.ref(`users/${targetUid}/fcmToken`).get();
    const token = userSnap.val();

    if (!token) {
        console.log(`No FCM token for ${targetUid}, skip poke.`);
        return;
    }

    // 2. Get Poker Name
    const pokerSnap = await db.ref(`users/${pokerUid}/profile/displayName`).get();
    const pokerName = pokerSnap.val() || "A Friend";

    const title = "Let's Play Ludo!";
    const body = reason === "game_in_progress"
        ? `${pokerName} is waiting! Tap to forfeit & join.`
        : `${pokerName} challenged you! Tap to play.`;

    // 3. Send
    try {
        await admin.messaging().send({
            token: token,
            notification: {
                title,
                body,
            },
            data: {
                type: "private_invite",
                hostUid: targetUid, // I am the host
                guestUid: pokerUid,
            },
            android: {
                priority: "high",
                notification: {
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
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
        console.log(`FCM sent to ${targetUid}`);
    } catch (e) {
        console.error("FCM Send Error", e);
    }
}
