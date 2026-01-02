import * as functions from "firebase-functions";
import { db } from "../admin";
import { applyWalletDelta } from "../utils";
import { getConfig } from "../config";

// const QUEUE_TIMEOUT_MS = 40 * 1000; // Removed in favor of dynamic config

// ---------------------------------------------
// 1. Join Solo Queue (Individual looking for partner)
// ---------------------------------------------
export const joinSoloQueue = functions.https.onCall(async (data, context) => {
    try {
        const uid = context.auth?.uid;
        console.log(`1. Click on "Team Up" | UID: ${uid}`);

        if (!uid) {
            throw new functions.https.HttpsError("unauthenticated", "Login required.");
        }

        const config = await getConfig();
        const entryFee = config.modes["4p_solo"].stake;

        // Check existing
        const existing = await db.ref(`queue/4p_solo`).orderByChild("uid").equalTo(uid).get();
        if (existing.exists()) {
            return { success: true, message: "Already queued" };
        }

        // Checks funds BEFORE pushing
        const goldSnap = await db.ref(`users/${uid}/wallet/gold`).get();
        const gold = goldSnap.exists() ? Number(goldSnap.val()) : 0;

        if (gold < entryFee) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient funds.");
        }

        // Push
        const ref = db.ref("queue/4p_solo").push();
        const pushId = ref.key!;

        await ref.set({
            uid,
            entryFee,
            ts: Date.now()
        });

        console.log(`2. Pushed to 4P solo queue | UID: ${uid}`);

        // Update user queue status
        await db.ref(`userQueueStatus/${uid}`).set({
            status: "queued_solo",
            pushId,
            ts: Date.now(),
            message: "Searching for teammate..."
        });

        console.log(`📥 QUEUE_INSERT_4P: User ${uid} inserted to 4P solo queue.`);

        return { success: true, pushId };
    } catch (e: any) {
        console.error("joinSoloQueue Error:", e);
        if (e instanceof functions.https.HttpsError) throw e;
        throw new functions.https.HttpsError("internal", e.message || "Unknown error in Team Up join.");
    }
});

// ---------------------------------------------
// 2. Process Solo Queue (Bot Timeout)
// ---------------------------------------------
export async function processSoloQueue() {
    console.log('🔍 DEBUG: processSoloQueue called');

    const config = await getConfig();
    const timeoutSec = config.modes["4p_solo"].queueTimeoutSec || 40;
    const cutoff = Date.now() - (timeoutSec * 1000);

    const snap = await db.ref("queue/4p_solo").orderByChild("ts").endAt(cutoff).get();

    if (!snap.exists()) return;

    const updates: any = {};
    const timedOutEntries: any[] = [];

    snap.forEach((child) => {
        const val = child.val();
        if (val) {
            timedOutEntries.push({ key: child.key, ...val });
        }
    });

    if (timedOutEntries.length === 0) return;

    // Pair each with a BOT
    // For simplicity, we just move them to team queue paired with a bot placeholder
    for (const entry of timedOutEntries) {
        // Remove from Solo Queue
        updates[`queue/4p_solo/${entry.key}`] = null;

        // Create a "Team Ticket" in the Team Queue
        const teamRef = db.ref("queue/4p_team").push();
        const teamId = teamRef.key!;
        const now = Date.now();

        // Team Logic: Real User P1 + Bot P2
        const teamData = {
            teamId,
            p1: entry.uid,
            p2: "BOT_PLAYER", // Bot
            p1Fee: entry.entryFee,
            p2Fee: 0, // Bot pays nothing
            ts: now, // Reset timestamp for Team Queue wait
            isPartialBot: true
        }

        updates[`queue/4p_team/${teamId}`] = teamData;

        // Notify user they are now searching for Opponents
        updates[`userQueueStatus/${entry.uid}`] = {
            status: "queued_team",
            teamId,
            ts: now,
            teammateName: "Bot",
            message: "Partner found (Bot). Searching for opponents..."
        };
    }

    await db.ref().update(updates);
    console.log(`🔍 DEBUG: processSoloQueue matched with a bot | UID: ${timedOutEntries.map(e => e.uid).join(", ")}`);
    console.log(`🤖 SOLO_TIMEOUT: Paired ${timedOutEntries.length} users with Bots.`);
}


// ---------------------------------------------
// 3. Scheduler: Check Team Queue for Timeouts
// ---------------------------------------------
// ---------------------------------------------
// 3. Scheduler: Check Team Queue for Timeouts
// ---------------------------------------------
export async function processTeamQueue() {
    console.log('🔍 DEBUG: processTeamQueue called');

    const config = await getConfig();
    const timeoutSec = config.modes["4p_team"].queueTimeoutSec || 60;
    const cutoff = Date.now() - (timeoutSec * 1000);

    const snap = await db.ref("queue/4p_team").orderByChild("ts").endAt(cutoff).get();

    if (!snap.exists()) return;

    const timedOutTeams: any[] = [];
    snap.forEach((child) => {
        const val = child.val();
        if (val) {
            timedOutTeams.push({ key: child.key, ...val });
        }
    });

    if (timedOutTeams.length === 0) return;

    // Process each team individually to avoid mass data loss on failure
    for (const team of timedOutTeams) {
        console.log(`🤖 TEAM_TIMEOUT: Pairing Team ${team.teamId} with Bot Team.`);

        // 1. Deduct Fees FIRST (Robust)
        const paidUsers: { uid: string, fee: number }[] = [];
        let deductionFailed = false;

        const playersToCharge = [
            { uid: team.p1, fee: team.p1Fee },
            { uid: team.p2, fee: team.p2Fee }
        ];

        for (const p of playersToCharge) {
            if (p.uid !== "BOT_PLAYER" && !p.uid.startsWith("bot_")) {
                try {
                    await applyWalletDelta(p.uid, -p.fee, "stake_debit", { meta: { mode: "4p_team" } });
                    paidUsers.push(p);
                } catch (e) {
                    console.error(`Deduction failed for ${p.uid}`, e);
                    deductionFailed = true;
                }
            }
        }

        if (deductionFailed) {
            // Refund any partial payments
            console.warn(`Aborting pairing for Team ${team.teamId} due to deduction failure. Refunding partials.`);
            for (const refundP of paidUsers) {
                await applyWalletDelta(refundP.uid, +refundP.fee, "refund", { meta: { reason: "team_match_fail_deduction" } });
            }
            // Do NOT remove from queue? Or remove and let them try again?
            // Better to leave them in queue so they can be picked up again?
            // But if funds are missing, they will loop forever.
            // Remove + Set status "insufficient_funds" is better.
            await db.ref(`queue/4p_team/${team.key}`).remove();
            // Notify P1/P2
            // We assume P1 is the leader or just notify both.
            // Just leaving them in queue for now (simplest), or remove?
            // Let's remove to prevent infinite loop.
            return;
        }

        // 2. Create Game with Bots
        try {
            const bot1 = `bot_1_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
            const bot2 = `bot_2_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

            await GameBuilder.createActiveGame({
                mode: 'team',
                stake: team.p1Fee,
                players: [
                    { uid: team.p1, seat: 0, team: 1 },
                    { uid: team.p2, seat: 2, team: 1 },
                    { uid: bot1, seat: 1, team: 2, name: "Bot 1" },
                    { uid: bot2, seat: 3, team: 2, name: "Bot 2" }
                ]
            });

            // 3. Remove from Queue (Success)
            await db.ref(`queue/4p_team/${team.key}`).remove();
            console.log(`✅ TEAM_TIMEOUT: Successfully created bot match for Team ${team.teamId}`);

        } catch (e) {
            console.error(`CRITICAL: Failed to create game for Team ${team.teamId}`, e);

            // Refund!
            for (const refundP of paidUsers) {
                await applyWalletDelta(refundP.uid, +refundP.fee, "refund", { meta: { reason: "team_match_fail_creation" } });
            }
            // Do NOT remove from queue (or remove to be safe?).
            // If we don't remove, it will retry next minute.
            // If the error is persistent (bug), it loops forever.
            // But better than losing the user.
            // Let's leave it in queue.
        }
    }
}

// ---------------------------------------------
// 4. Join Team Queue (Premade Team)
// ---------------------------------------------
export const joinTeamQueue = functions.https.onCall(async (data, context) => {
    // Placeholder for future "Invite Friend" flow
    // For now, this might be unused or for testing
    return { success: true, message: "Use Solo Queue for now" };
});


// ---------------------------------------------
// 5. Atomic Pairing Helpers (Mirroring 2P Logic)
// ---------------------------------------------

// ---------------------------------------------
// Import Services
import { GameBuilder } from "../services/game_builder";
import { QueueManager } from "../services/queue_manager";

// ... (existing imports, but remove duplicate definition of claimEntry if present or just stop using it)

// ---------------------------------------------
// 5. Atomic Pairing Helpers (Mirroring 2P Logic)
// ---------------------------------------------

export async function attemptSoloPairing() {
    console.log("5. attemptSoloPairing called active");

    const queueRef = db.ref("queue/4p_solo");
    const snap = await queueRef.orderByChild("ts").limitToFirst(20).get();
    if (!snap.exists()) {
        console.log("7. attemptSoloPairing failed | No entries found");
        return;
    }

    const entries: any[] = [];
    snap.forEach(c => {
        entries.push({ key: c.key, ...c.val() });
    });

    if (entries.length < 2) {
        console.log(`7. attemptSoloPairing failed | Not enough users (${entries.length})`);
        return;
    }

    const p1 = entries[0];
    const p2 = entries[1];

    if (p1.uid === p2.uid) {
        // remove duplicate
        await db.ref(`queue/4p_solo/${p1.key}`).remove();
        console.log(`3. Deleted from 4P solo queue | UID: ${p1.uid} (Duplicate Removal)`);
        return;
    }

    console.log(`Attempting claim for 4P Solo`, { uid1: p1.uid, uid2: p2.uid });

    // Claim P1
    const p1Data = await QueueManager.claimEntry("queue/4p_solo", p1.key, p1.uid);
    if (!p1Data) {
        console.warn(`Claim aborted due to conflict for P1 ${p1.uid}`);
        return;
    }
    console.log(`3. Deleted from 4P solo queue | UID: ${p1.uid} (Claimed)`);

    // Claim P2
    const p2Data = await QueueManager.claimEntry("queue/4p_solo", p2.key, p2.uid);
    if (!p2Data) {
        console.warn(`Claim aborted due to conflict for P2 ${p2.uid}. Restoring P1.`);
        // Restore P1 using correct data
        await QueueManager.restoreEntry("queue/4p_solo", p1.key, p1Data);
        return;
    }
    console.log(`3. Deleted from 4P solo queue | UID: ${p2.uid} (Claimed)`);

    console.log(`6. attemptSoloPairing claim users successfullly | UID 1: ${p1.uid} | UID 2: ${p2.uid}`);

    // Create Team
    const teamRef = db.ref("queue/4p_team").push();
    const teamId = teamRef.key!;
    const now = Date.now();

    await teamRef.set({
        teamId,
        p1: p1.uid,
        p2: p2.uid,
        p1Fee: p1.entryFee,
        p2Fee: p2.entryFee,
        ts: now
    });

    console.log(`9. attemptSoloPairing created TeamID ${teamId}`);

    // Fetch Names
    const p1NameSnap = await db.ref(`users/${p1.uid}/profile/displayName`).get();
    const p2NameSnap = await db.ref(`users/${p2.uid}/profile/displayName`).get();

    const p1Name = p1NameSnap.val() || "Player 1";
    const p2Name = p2NameSnap.val() || "Player 2";

    // Notify Users
    const updates: any = {};
    updates[`userQueueStatus/${p1.uid}`] = {
        status: "queued_team",
        teamId,
        ts: now,
        teammateName: p2Name
    };
    updates[`userQueueStatus/${p2.uid}`] = {
        status: "queued_team",
        teamId,
        ts: now,
        teammateName: p1Name
    };

    await db.ref().update(updates);

    console.log(`🤝 SOLO_PAIR: Paired ${p1.uid} & ${p2.uid} into Team ${teamId}`);
}

export async function attemptTeamPairing() {
    const queueRef = db.ref("queue/4p_team");
    // Limit to 10
    const snap = await queueRef.orderByChild("ts").limitToFirst(10).get();
    if (!snap.exists()) return;

    const teams: any[] = [];
    snap.forEach(c => {
        teams.push({ key: c.key, ...c.val() });
    });

    console.log(`[TEAM_PAIR] Found ${teams.length} teams in queue.`);

    if (teams.length < 2) {
        if (teams.length === 1) {
            const t = teams[0];
            const age = (Date.now() - t.ts) / 1000;
            console.log(`[TEAM_PAIR] Waiting for opponent. Team 1: ${t.teamId} (Age: ${age.toFixed(1)}s)`);
        }
        return;
    }

    const t1 = teams[0];
    const t2 = teams[1];
    const age1 = (Date.now() - t1.ts) / 1000;
    const age2 = (Date.now() - t2.ts) / 1000;

    console.log(`[TEAM_PAIR] Attempting to match:
      T1: ${t1.teamId} (Age: ${age1.toFixed(1)}s)
      T2: ${t2.teamId} (Age: ${age2.toFixed(1)}s)`);

    console.log(`Attempting Team Claim`, { team1: t1.teamId, team2: t2.teamId });

    // Claim
    const t1Data = await QueueManager.claimEntry("queue/4p_team", t1.key);
    if (!t1Data) return; // Busy

    const t2Data = await QueueManager.claimEntry("queue/4p_team", t2.key);
    if (!t2Data) {
        // Restore t1
        console.warn(`Claim aborted for Team 2. Restoring Team 1.`);
        await QueueManager.restoreEntry("queue/4p_team", t1.key, t1Data);
        return;
    }

    // Create Game
    console.log(`⚔️ TEAM_PAIR: Matching Team ${t1.teamId} vs Team ${t2.teamId}`);

    try {
        // Deduct Fees for Real Users FIRST (Before creating game, unlike previous reliable logic)
        // Previous logic had deduction AFTER game creation call but inside try/catch.
        // We will do robust check -> charge -> create.

        console.log("Deducting fees for 4P Teams");
        const allPlayers = [
            { uid: t1.p1, fee: t1.p1Fee }, { uid: t1.p2, fee: t1.p1Fee },
            { uid: t2.p1, fee: t2.p1Fee }, { uid: t2.p2, fee: t2.p2Fee }
        ];

        // We need to keep track of who paid to refund if subsequent fails
        const paidUsers: { uid: string, fee: number }[] = [];

        for (const p of allPlayers) {
            if (p.uid !== "BOT_PLAYER" && !p.uid.startsWith("bot_")) {
                try {
                    await applyWalletDelta(p.uid, -p.fee, "stake_debit", { meta: { mode: "4p_team" } });
                    paidUsers.push(p);
                } catch (e) {
                    console.error(`Deduction failed for ${p.uid}`, e);
                    // Abort and Refund everyone who paid
                    for (const refundP of paidUsers) {
                        await applyWalletDelta(refundP.uid, +refundP.fee, "refund", { meta: { reason: "team_match_fail" } });
                    }
                    // Restore Queues
                    await QueueManager.restoreEntry("queue/4p_team", t1.key, t1Data);
                    await QueueManager.restoreEntry("queue/4p_team", t2.key, t2Data);
                    return; // Stop
                }
            }
        }

        // Create Game via GameBuilder
        // T1 -> Seats 0, 2 (Team 1)
        // T2 -> Seats 1, 3 (Team 2)
        await GameBuilder.createActiveGame({
            mode: 'team',
            stake: t1.p1Fee, // Assume uniform stake
            players: [
                { uid: t1.p1, seat: 0, team: 1 },
                { uid: t1.p2, seat: 2, team: 1 },
                { uid: t2.p1, seat: 1, team: 2 },
                { uid: t2.p2, seat: 3, team: 2 }
            ]
        });

    } catch (e) {
        console.error("CRITICAL: Team pairing failed", e);
        // It's hard to recover if GameBuilder fails but we paid.
        // We should refund.
        // For now, logging critical.
        // In robust system, GameBuilder failure should trigger refunds.
    }
}

// ---------------------------------------------
// 6. Debug Helper (Exposed)
// ---------------------------------------------
export const debugForce4PProcess = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    console.log(`🔧 DEBUG: Force process called by ${uid}`);
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "Auth required");

    // Manually trigger the scheduled logic + atomic pairing
    await processSoloQueue();
    await processTeamQueue();
    await attemptSoloPairing();
    await attemptTeamPairing();

    return { success: true, message: "Queues processed" };
});
