import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, connectAuthEmulator } from 'firebase/auth';
import { getDatabase, ref, onValue, set, connectDatabaseEmulator } from 'firebase/database';
import { getFunctions, httpsCallable, connectFunctionsEmulator } from 'firebase/functions';

// Config from lib/firebase_options.dart (Web)
const firebaseConfig = {
    apiKey: 'AIzaSyDijh_5yVX4bJSG_QI8sDTqH4uINq6yt2Y',
    appId: '1:481131505194:web:a6927e28e932d11648c553',
    messagingSenderId: '481131505194',
    projectId: 'tryb-ludo-v1',
    authDomain: 'tryb-ludo-v1.firebaseapp.com',
    storageBucket: 'tryb-ludo-v1.firebasestorage.app',
    measurementId: 'G-DX930DLSVF',
};

// Initialize two separate apps to simulate two users
const app1 = initializeApp(firebaseConfig, 'user1');
const app2 = initializeApp(firebaseConfig, 'user2');

const auth1 = getAuth(app1);
const auth2 = getAuth(app2);
const db1 = getDatabase(app1);
const db2 = getDatabase(app2);
const functions1 = getFunctions(app1);
const functions2 = getFunctions(app2);

// Uncomment to use emulators if running locally with emulators
// connectAuthEmulator(auth1, "http://127.0.0.1:9099");
// connectAuthEmulator(auth2, "http://127.0.0.1:9099");
// connectDatabaseEmulator(db1, "127.0.0.1", 9000);
// connectDatabaseEmulator(db2, "127.0.0.1", 9000);
// connectFunctionsEmulator(functions1, "127.0.0.1", 5001);
// connectFunctionsEmulator(functions2, "127.0.0.1", 5001);

async function runTest() {
    try {
        console.log('Signing in users...');
        const cred1 = await signInAnonymously(auth1);
        const cred2 = await signInAnonymously(auth2);
        console.log(`User 1: ${cred1.user.uid}`);
        console.log(`User 2: ${cred2.user.uid}`);

        // Seed gold
        await set(ref(db1, `users/${cred1.user.uid}/gold`), 1000);
        await set(ref(db2, `users/${cred2.user.uid}/gold`), 1000);
        console.log('Seeded gold for users.');

        // Listen for status updates
        const p1StatusRef = ref(db1, `userQueueStatus/${cred1.user.uid}`);
        const p2StatusRef = ref(db2, `userQueueStatus/${cred2.user.uid}`);

        let p1Paired = false;
        let p2Paired = false;

        onValue(p1StatusRef, (snap) => {
            const val = snap.val();
            if (val) {
                console.log(`User 1 Status: ${val.status}`);
                if (val.status === 'paired') {
                    p1Paired = true;
                    checkDone();
                }
            }
        });

        onValue(p2StatusRef, (snap) => {
            const val = snap.val();
            if (val) {
                console.log(`User 2 Status: ${val.status}`);
                if (val.status === 'paired') {
                    p2Paired = true;
                    checkDone();
                }
            }
        });

        function checkDone() {
            if (p1Paired && p2Paired) {
                console.log('SUCCESS: Both users paired!');
                process.exit(0);
            }
        }

        console.log('User 1 joining queue...');
        const join1 = httpsCallable(functions1, 'join2PQueue');
        await join1({ entryFee: 100 });
        console.log('User 1 joined.');

        // Wait a bit
        await new Promise(r => setTimeout(r, 2000));

        console.log('User 2 joining queue...');
        const join2 = httpsCallable(functions2, 'join2PQueue');
        await join2({ entryFee: 100 });
        console.log('User 2 joined.');

        // Wait for pairing (timeout 30s)
        setTimeout(() => {
            console.error('TIMEOUT: Pairing did not happen in time.');
            process.exit(1);
        }, 30000);

    } catch (e) {
        console.error('Error:', e);
        process.exit(1);
    }
}

runTest();
