import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getDatabase, ref, onValue, set, get } from 'firebase/database';
import { getFunctions, httpsCallable } from 'firebase/functions';

const firebaseConfig = {
    apiKey: 'AIzaSyDijh_5yVX4bJSG_QI8sDTqH4uINq6yt2Y',
    appId: '1:481131505194:web:a6927e28e932d11648c553',
    messagingSenderId: '481131505194',
    projectId: 'tryb-ludo-v1',
    authDomain: 'tryb-ludo-v1.firebaseapp.com',
    storageBucket: 'tryb-ludo-v1.firebasestorage.app',
    measurementId: 'G-DX930DLSVF',
};

const app1 = initializeApp(firebaseConfig, 'user1');
const app2 = initializeApp(firebaseConfig, 'user2');

const auth1 = getAuth(app1);
const auth2 = getAuth(app2);
const db1 = getDatabase(app1);
const db2 = getDatabase(app2);
const functions1 = getFunctions(app1);
const functions2 = getFunctions(app2);

async function runGameTest() {
    try {
        console.log('🔐 Signing in users...');
        const cred1 = await signInAnonymously(auth1);
        const cred2 = await signInAnonymously(auth2);
        console.log(`✅ User 1: ${cred1.user.uid}`);
        console.log(`✅ User 2: ${cred2.user.uid}`);

        // Seed gold
        await set(ref(db1, `users/${cred1.user.uid}/gold`), 1000);
        await set(ref(db2, `users/${cred2.user.uid}/gold`), 1000);
        console.log('💰 Seeded gold for both users.');

        // Join queue
        console.log('\n🎮 User 1 joining queue...');
        const join1 = httpsCallable(functions1, 'join2PQueue');
        await join1({ entryFee: 100 });

        console.log('🎮 User 2 joining queue...');
        const join2 = httpsCallable(functions2, 'join2PQueue');
        await join2({ entryFee: 100 });

        // Wait for pairing
        console.log('\n⏳ Waiting for pairing (5 seconds)...');
        await new Promise(r => setTimeout(r, 5000));

        // Check user1 status for gameId
        const status1Snap = await get(ref(db1, `userQueueStatus/${cred1.user.uid}`));
        const status1 = status1Snap.val();

        if (!status1 || status1.status !== 'paired') {
            console.error('❌ User 1 not paired');
            process.exit(1);
        }

        const gameId = status1.gameId;
        console.log(`\n✅ Users paired! Game ID: ${gameId}`);

        // Read game state
        const gameSnap = await get(ref(db1, `games/${gameId}`));
        const game = gameSnap.val();

        console.log('\n📊 Initial Game State:');
        console.log('  Mode:', game.mode);
        console.log('  State:', game.state);
        console.log('  Turn:', game.turn);
        console.log('  Board:', JSON.stringify(game.board));
        console.log('  Players:', Object.keys(game.players));

        // Verify schema
        if (!game.mode || !game.state || !game.turn || !game.board) {
            console.error('❌ Game schema incomplete');
            process.exit(1);
        }

        console.log('\n✅ Game schema validated!');

        // Test Move
        console.log('\n🎲 Testing submitMove...');
        const submitMove = httpsCallable(functions1, 'submitMove');

        try {
            const result = await submitMove({
                gameId,
                tokenIndex: 0,
                diceValue: 6
            });
            console.log('✅ Move submitted:', result.data);
        } catch (e: any) {
            console.error('❌ Move failed:', e.message);
            process.exit(1);
        }

        // Check updated game state
        await new Promise(r => setTimeout(r, 1000));
        const updatedGameSnap = await get(ref(db1, `games/${gameId}`));
        const updatedGame = updatedGameSnap.val();

        console.log('\n📊 Updated Game State:');
        console.log('  Board:', JSON.stringify(updatedGame.board));
        console.log('  Last Move:', JSON.stringify(updatedGame.lastMove));

        console.log('\n✅ All tests passed!');
        process.exit(0);

    } catch (e) {
        console.error('❌ Error:', e);
        process.exit(1);
    }
}

runGameTest();
