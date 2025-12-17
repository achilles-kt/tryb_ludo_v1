const firebase = require("firebase/compat/app");
require("firebase/compat/auth");
require("firebase/compat/database");
require("firebase/compat/functions");

const firebaseConfig = {
    apiKey: 'AIzaSyDijh_5yVX4bJSG_QI8sDTqH4uINq6yt2Y',
    authDomain: 'tryb-ludo-v1.firebaseapp.com',
    projectId: 'tryb-ludo-v1',
    storageBucket: 'tryb-ludo-v1.firebasestorage.app',
    messagingSenderId: '481131505194',
    appId: '1:481131505194:web:a6927e28e932d11648c553',
    measurementId: 'G-DX930DLSVF',
    databaseURL: 'https://tryb-ludo-v1-default-rtdb.firebaseio.com'
};

// Initialize TWO apps to simulate two distinct clients
console.log("Initializing Apps...");
const hostApp = firebase.initializeApp(firebaseConfig, "HOST");
const guestApp = firebase.initializeApp(firebaseConfig, "GUEST");

async function runSimulation() {
    try {
        console.log("🚀 Starting E2E Invite Simulation (Compat Mode)...");

        // 1. Authenticate both users
        console.log("--- Authentication ---");
        const hostUser = await hostApp.auth().signInAnonymously();
        const guestUser = await guestApp.auth().signInAnonymously();
        const hostUid = hostUser.user.uid;
        const guestUid = guestUser.user.uid;
        console.log(`✅ Host: ${hostUid}`);
        console.log(`✅ Guest: ${guestUid}`);

        // 2. Host Listen for Invites
        console.log("\n--- Host Listening ---");
        const hostDb = hostApp.database();
        const invitesRef = hostDb.ref("invites");

        let inviteReceivedPromise = new Promise((resolve) => {
            const query = invitesRef.orderByChild("hostUid").equalTo(hostUid);
            query.on("child_added", (snapshot) => {
                const val = snapshot.val();
                if (val.status === 'pending') {
                    console.log(`📩 Host received invite: ${snapshot.key}`, val);
                    resolve(snapshot.key);
                }
            }, (error) => {
                console.error("❌ Host Listener Error:", error.message);
            });
        });

        // 3. Guest Sends Invite
        console.log("\n--- Guest Sending Invite ---");
        const guestFunctions = guestApp.functions();
        // guestFunctions.useEmulator("localhost", 5001); 
        const sendInvite = guestFunctions.httpsCallable("sendInvite");

        const sendResult = await sendInvite({ hostUid: hostUid });
        const inviteId = sendResult.data.inviteId;
        console.log(`✅ Guest Sent Invite. ID: ${inviteId}`);

        // 4. Wait for Host to Receive
        console.log("\n--- Waiting for Host Receipt ---");
        const receivedInviteId = await inviteReceivedPromise;
        if (receivedInviteId !== inviteId) {
            throw new Error(`ID Mismatch! Sent: ${inviteId}, Received: ${receivedInviteId}`);
        }
        console.log("✅ Host successfully detected invite via RTDB listener.");

        // 5. Host Accepts Invite
        console.log("\n--- Host Accepting Invite ---");
        // NOTE: We need to use hostApp's functions instance to be authenticated as Host
        const hostFunctions = hostApp.functions();
        const respondToInvite = hostFunctions.httpsCallable("respondToInvite");

        const respondResult = await respondToInvite({ inviteId: inviteId, response: "accept" });
        console.log("✅ Host Responded:", respondResult.data);
        const { gameId, tableId } = respondResult.data;

        if (!gameId || !tableId) throw new Error("Missing gameId/tableId in response");

        // 6. Verify Database State (Guest checks)
        console.log("\n--- Guest Verifying State ---");
        const guestDb = guestApp.database();
        const inviteSnap = await guestDb.ref(`invites/${inviteId}`).once("value");
        const finalInvite = inviteSnap.val();

        console.log("Final Invite State:", finalInvite);
        if (finalInvite.status !== "accepted") throw new Error("Invite status should be accepted");
        if (finalInvite.gameId !== gameId) throw new Error("Game ID mismatch in DB");

        console.log("\n🎉 SUCCESS: End-to-End Invite Flow Verified!");
        process.exit(0);

    } catch (error) {
        console.error("\n❌ SIMULATION FAILED:", error);
        process.exit(1);
    }
}

runSimulation();
