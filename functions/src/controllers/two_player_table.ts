import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig } from "../config";
import { GameBuilder } from "../services/game_builder";
import { QueueManager } from "../services/queue_manager";
import { applyWalletDelta } from "../utils";

// Types
type QEntry = {
    pushId: string;
    uid: string;
    entryFee: number;
    ts: number;
};

// ---------------------------------------------
// 2P Pairing Logic
// ---------------------------------------------
export async function attemptPairing() {
    const queueRef = db.ref("queue/2p");

    // 1. Fetch Candidates directly
    const snap = await queueRef.orderByChild("ts").limitToFirst(20).get();
    if (!snap.exists()) return; // No one waiting

    const allEntries: QEntry[] = [];
    snap.forEach((child) => {
        const val = child.val();
        if (!val || !val.uid) return;
        allEntries.push({
            pushId: child.key!,
            uid: String(val.uid),
            entryFee: Number(val.entryFee) || 0,
            ts: Number(val.ts) || 0,
        });
    });

    if (allEntries.length < 2) return;

    // Sort & Distinct
    allEntries.sort((a, b) => a.ts - b.ts);
    const distinct: QEntry[] = [];
    const seen = new Set<string>();
    for (const e of allEntries) {
        if (!seen.has(e.uid)) {
            seen.add(e.uid);
            distinct.push(e);
        }
        if (distinct.length === 2) break;
    }

    if (distinct.length < 2) return;

    const p1 = distinct[0];
    const p2 = distinct[1];

    console.log(`Attempting claim`, { uid1: p1.uid, uid2: p2.uid });

    // 2. Atomic Claim (QueueManager)
    const p1ToClaim = await QueueManager.claimEntry("queue/2p", p1.pushId, p1.uid);
    if (!p1ToClaim) return;

    const p2ToClaim = await QueueManager.claimEntry("queue/2p", p2.pushId, p2.uid);
    if (!p2ToClaim) {
        await QueueManager.restoreEntry("queue/2p", p1.pushId, p1ToClaim);
        return;
    }

    // 3. Deduct Stakes
    const config = await getConfig();
    const stake = config.modes['2p'].stake;

    try {
        await applyWalletDelta(p1.uid, -stake, "stake_debit", { currency: 'gold', meta: { stake, mode: "2p" } });
        try {
            await applyWalletDelta(p2.uid, -stake, "stake_debit", { currency: 'gold', meta: { stake, mode: "2p" } });
        } catch (e2) {
            // P2 failed, refund P1
            await applyWalletDelta(p1.uid, +stake, "refund", { currency: 'gold' });
            throw e2; // Re-throw to handle restore
        }
    } catch (e) {
        console.error("Wallet failure in 2P pairing", e);
        // Restore both to queue
        await QueueManager.restoreEntry("queue/2p", p1.pushId, p1ToClaim);
        await QueueManager.restoreEntry("queue/2p", p2.pushId, p2ToClaim);
        return;
    }

    // 4. Create Game (GameBuilder)
    await GameBuilder.createActiveGame({
        mode: '2p',
        stake,
        players: [
            { uid: p1.uid, seat: 0 },
            { uid: p2.uid, seat: 2 }
        ]
    });
}
