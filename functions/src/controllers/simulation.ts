import * as functions from "firebase-functions";
import { db } from "../admin";
import { attemptSoloPairing, attemptTeamPairing, processSoloQueue, processTeamQueue } from "./team_table";
import { attemptPairing } from "./two_player_table";
import { getConfig } from "../config";
import { sendInviteLogic, respondToInviteLogic } from "./invites";

// Helper to clear state
async function clearState(users: string[]) {
    await db.ref("queue/4p_solo").remove();
    await db.ref("queue/4p_team").remove();
    await db.ref("queue/2p").remove();
    const updates: any = {};
    for (const uid of users) {
        updates[`users/${uid}/wallet/gold`] = 5000;
        updates[`userQueueStatus/${uid}`] = null;
        updates[`userGameStatus/${uid}`] = null;
    }
    await db.ref().update(updates);
}

// Logic: Team Up
async function runTeamUpTest(logs: string[]) {
    const log = (msg: string) => { console.log(msg); logs.push(msg); };
    log("🚀 Starting Team Up Simulation...");
    const users = ["sim_u1", "sim_u2", "sim_u3", "sim_u4"];
    await clearState(users);
    log("1. Cleared State");
    const config = await getConfig();
    const stake = config.modes["4p_team"].stake;
    const team1Ref = db.ref("queue/4p_team").push();
    const team2Ref = db.ref("queue/4p_team").push();
    await team1Ref.set({ p1: users[0], p2: users[1], stake, p1Fee: stake, p2Fee: stake, ts: Date.now() });
    await team2Ref.set({ p1: users[2], p2: users[3], stake, p1Fee: stake, p2Fee: stake, ts: Date.now() });
    log("2. Added 2 Teams to Queue");
    await attemptTeamPairing();
    log("3. Ran attemptTeamPairing");
    const gamesSnap = await db.ref("games").limitToLast(1).get();
    let gameId = "";
    gamesSnap.forEach(c => { gameId = c.key!; });
    if (!gameId) {
        log("❌ FAILURE: No game created");
        throw new Error("No game created");
    }
    log(`✅ SUCCESS: Team Game Created! ID: ${gameId}`);
    return gameId;
}

// Logic: Bot Fallback
async function runTeamBotFallbackTest(logs: string[]) {
    const log = (msg: string) => { console.log(msg); logs.push(msg); };
    log("🚀 Starting Team Bot Fallback Simulation...");
    const users = ["sim_u_timeout_1", "sim_u_timeout_2"];
    await clearState(users);
    await db.ref("queue/4p_team").remove();
    log("1. Cleared State. Simulating TIMEOUT.");
    const config = await getConfig();
    const stake = config.modes["4p_team"].stake;
    const teamRef = db.ref("queue/4p_team").push();
    await teamRef.set({
        p1: users[0],
        p2: users[1],
        stake, p1Fee: stake, p2Fee: stake,
        ts: Date.now() - (61 * 1000) // 61s ago
    });
    log("2. Added OLD Team to Queue");
    await processTeamQueue();
    log("3. Ran processTeamQueue (should trigger bot match)");

    // Lookup game via User Status (More robust than limitToLast)
    const p1StatusSnap = await db.ref(`userGameStatus/${users[0]}`).get();
    const p1Status = p1StatusSnap.val();
    if (!p1Status || !p1Status.gameId) {
        log("❌ FAILURE: No game created for user (User Game Status missing)");
        throw new Error("No game created");
    }
    const gameId = p1Status.gameId;
    const gameSnap = await db.ref(`games/${gameId}`).get();
    const game = gameSnap.val();
    if (!game) {
        log("❌ FAILURE: Game data missing for ID " + gameId);
        throw new Error("Game data missing");
    }

    const hasBot = Object.keys(game.players).some((uid) => uid.includes("bot"));
    if (!hasBot) {
        log(`❌ FAILURE: Game created but NO BOTS found. Players: ${JSON.stringify(game.players)}`);
        throw new Error("Game created without bots");
    }
    log(`✅ SUCCESS: Bot Game Created! ID: ${gameId}`);
    return gameId;
}

// Logic: 2P
async function run2PTest(logs: string[]) {
    const log = (msg: string) => { console.log(msg); logs.push(msg); };
    log("🚀 Starting 2P Simulation...");
    const users = ["sim_2p_1", "sim_2p_2"];
    await clearState(users);
    const config = await getConfig();
    const stake = config.modes['2p'].stake;
    log(`1. Cleared 2P State. Stake is ${stake}`);
    const qv = { entryFee: stake, ts: Date.now() };
    await db.ref("queue/2p").push({ ...qv, uid: users[0] });
    await db.ref("queue/2p").push({ ...qv, uid: users[1] });
    log("2. Added 2 users to 2P Queue");
    await attemptPairing();
    log("3. Ran attemptPairing");
    const gamesSnap = await db.ref("games").limitToLast(1).get();
    let gameId = "";
    gamesSnap.forEach(c => { gameId = c.key!; });
    if (!gameId) {
        log("❌ FAILURE: No game created");
        throw new Error("No game created");
    }
    log(`✅ SUCCESS: 2P Game Created! ID: ${gameId}`);
    return gameId;
}

// Logic: Invites
async function runInviteTest(logs: string[]) {
    const log = (msg: string) => { console.log(msg); logs.push(msg); };
    log("🚀 Starting Invite Flow Simulation...");
    const host = "sim_host_1";
    const guest = "sim_guest_1";
    const users = [host, guest];
    await clearState(users);
    await db.ref("invites").remove();
    log("1. Reset Host/Guest State");
    log(`2. Guest ${guest} sending invite to ${host}...`);
    const sendResult = await sendInviteLogic(guest, host);
    if (!sendResult.success) {
        log(`❌ FAILURE: Send Invite failed`);
        throw new Error("Send Invite Failed");
    }
    const inviteId = sendResult.inviteId!;
    log(`   - Invite Sent! ID: ${inviteId}`);
    log(`3. Host ${host} accepting invite...`);
    const respondResult = await respondToInviteLogic(host, inviteId, "accept");
    if (!respondResult.success) {
        log(`❌ FAILURE: Respond Invite failed`);
        throw new Error("Respond Invite Failed");
    }
    const gameId = respondResult.gameId;
    log(`   - Invite Accepted! Game: ${gameId}`);
    const gameSnap = await db.ref(`games/${gameId}`).get();
    const game = gameSnap.val();
    if (game.mode !== 'private') {
        log(`❌ FAILURE: Game mode is ${game.mode}`);
        throw new Error("Incorrect Game Mode");
    }
    log(`✅ SUCCESS: Invite Game Created! ID: ${gameId}`);
    return gameId;
}

// Exports
export const testTeamUpFlow = functions.https.onCall(async (data, context) => {
    const logs: string[] = [];
    try { await runTeamUpTest(logs); return { success: true, logs }; }
    catch (e: any) { return { success: false, logs, error: e.message }; }
});

export const testTeamBotFallback = functions.https.onCall(async (data, context) => {
    const logs: string[] = [];
    try { await runTeamBotFallbackTest(logs); return { success: true, logs }; }
    catch (e: any) { return { success: false, logs, error: e.message }; }
});

export const test2PFlow = functions.https.onCall(async (data, context) => {
    const logs: string[] = [];
    try { await run2PTest(logs); return { success: true, logs }; }
    catch (e: any) { return { success: false, logs, error: e.message }; }
});

export const testInviteFlow = functions.https.onCall(async (data, context) => {
    const logs: string[] = [];
    try { await runInviteTest(logs); return { success: true, logs }; }
    catch (e: any) { return { success: false, logs, error: e.message }; }
});

export const testAllFlows = functions.https.onCall(async (data, context) => {
    const logs: string[] = [];
    const results: any = {};
    logs.push("=== STARTING ALL FLOWS TEST ===");

    try {
        await run2PTest(logs);
        results['2P'] = "PASSED";
    } catch (e) { results['2P'] = "FAILED"; }

    try {
        await runTeamUpTest(logs);
        results['TeamUp'] = "PASSED";
    } catch (e) { results['TeamUp'] = "FAILED"; }

    try {
        await runTeamBotFallbackTest(logs);
        results['TeamBot'] = "PASSED";
    } catch (e) { results['TeamBot'] = "FAILED"; }

    try {
        await runInviteTest(logs);
        results['Invite'] = "PASSED";
    } catch (e) { results['Invite'] = "FAILED"; }

    logs.push("=== ALL TESTS COMPLETED ===");
    return { success: true, logs, results };
});
