const firebase = require("firebase/compat/app");
require("firebase/compat/functions");
require("firebase/compat/auth");

const firebaseConfig = {
    apiKey: 'AIzaSyDijh_5yVX4bJSG_QI8sDTqH4uINq6yt2Y',
    authDomain: 'tryb-ludo-v1.firebaseapp.com',
    projectId: 'tryb-ludo-v1',
    databaseURL: 'https://tryb-ludo-v1-default-rtdb.firebaseio.com',
    appId: '1:481131505194:web:a6927e28e932d11648c553',
};

async function run() {
    console.log("🚀 invoking debugForce4PProcess...");
    const app = firebase.initializeApp(firebaseConfig);
    // Auth generic
    await app.auth().signInAnonymously();

    const functions = app.functions("us-central1"); // Ensure region
    // Local emulator? No, live.

    try {
        const force = functions.httpsCallable("debugForce4PProcess");
        const res = await force({});
        console.log("Result:", res.data);
        process.exit(0);
    } catch (e) {
        console.error("Error:", e);
        process.exit(1);
    }
}

run();
