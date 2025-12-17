const firebase = require("firebase/compat/app");
require("firebase/compat/database");
require("firebase/compat/auth");

const firebaseConfig = {
    apiKey: 'AIzaSyDijh_5yVX4bJSG_QI8sDTqH4uINq6yt2Y',
    authDomain: 'tryb-ludo-v1.firebaseapp.com',
    projectId: 'tryb-ludo-v1',
    databaseURL: 'https://tryb-ludo-v1-default-rtdb.firebaseio.com',
    appId: '1:481131505194:web:a6927e28e932d11648c553',
};

async function getAuthenticatedUser(name) {
    const app = firebase.initializeApp(firebaseConfig, name);
    await app.auth().signInAnonymously();
    const user = app.auth().currentUser;
    return { app, uid: user.uid, db: app.database() };
}

async function runTest() {
    console.log("🚀 Starting Team Trigger Verification (Multi-User Auth)...");

    try {
        // Init 4 Users
        console.log("authenticating users...");
        const p1 = await getAuthenticatedUser("player1");
        const p2 = await getAuthenticatedUser("player2");
        const p3 = await getAuthenticatedUser("player3");
        const p4 = await getAuthenticatedUser("player4");

        console.log(`User IDs:
        P1: ${p1.uid}
        P2: ${p2.uid}
        P3: ${p3.uid}
        P4: ${p4.uid}`);
        if (p4.uid) await p4.db.ref(`userQueueStatus/${p4.uid}`).remove();

        console.log("\n--- Pushing P1 & P2 to 4p_solo ---");
        const ts = firebase.database.ServerValue.TIMESTAMP;

        await p1.db.ref("queue/4p_solo").push().set({
            uid: p1.uid,
            entryFee: 500,
            ts: ts
        });

        // P2 joins shortly after
        await new Promise(r => setTimeout(r, 100)); // 100ms delay
        await p2.db.ref("queue/4p_solo").push().set({
            uid: p2.uid,
            entryFee: 500,
            ts: ts
        });

        console.log("Waiting for Solo Trigger to pair P1 & P2...");

        let teamId = null;
        await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error("Timeout waiting for Team")), 30000);
            const sub = p1.db.ref(`userQueueStatus/${p1.uid}`).on("value", (snap) => {
                const val = snap.val();
                if (val && val.status === "queued_team" && val.teamId) {
                    teamId = val.teamId;
                    clearTimeout(timeout);
                    p1.db.ref(`userQueueStatus/${p1.uid}`).off("value", sub);
                    resolve();
                }
            });
        });

        console.log(`✅ SUCCESS: Team Formed ID: ${teamId}`);

        console.log(`\n--- Pushing P3 & P4 to 4p_solo ---`);

        // P3 Joins
        await p3.db.ref("queue/4p_solo").push().set({ uid: p3.uid, entryFee: 500, ts: Date.now() + 20 });
        // P4 Joins
        await p4.db.ref("queue/4p_solo").push().set({ uid: p4.uid, entryFee: 500, ts: Date.now() + 30 });

        console.log("Waiting for Game Creation for P1...");
        let gameId = null;

        await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error("Timeout waiting for Game")), 20000);
            const sub = p1.db.ref(`userGameStatus/${p1.uid}`).on("value", (snap) => {
                const val = snap.val();
                if (val && val.gameId) {
                    gameId = val.gameId;
                    clearTimeout(timeout);
                    p1.db.ref(`userGameStatus/${p1.uid}`).off("value", sub);
                    resolve();
                }
            });
        });

        console.log(`✅ SUCCESS: Game Created ID: ${gameId}`);
        process.exit(0);

    } catch (e) {
        console.error("\n❌ FAILED:", e.message);
        process.exit(1);
    }
}

runTest();
