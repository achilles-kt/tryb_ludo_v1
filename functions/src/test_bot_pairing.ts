import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getDatabase, ref, get, onValue } from 'firebase/database';
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

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getDatabase(app);
const functions = getFunctions(app);

async function testBotPairing() {
    try {
        console.log('🔐 Signing in...');
        const cred = await signInAnonymously(auth);
        console.log(`✅ User: ${cred.user.uid}`);

        // Check initial gold
        const initialGoldSnap = await get(ref(db, `users/${cred.user.uid}/gold`));
        const initialGold = initialGoldSnap.val();
        console.log(`💰 Initial gold: ${initialGold}`);

        // Join queue
        console.log('\n🎮 Joining queue...');
        const join = httpsCallable(functions, 'join2PQueue');
        await join({ entryFee: 100 });
        console.log('✅ Joined queue');

        // Wait 90 seconds for bot pairing (scheduler runs every minute)
        console.log('\n⏳ Waiting 90 seconds for bot pairing...');
        await new Promise(r => setTimeout(r, 90000));

        // Check if paired
        const statusSnap = await get(ref(db, `userQueueStatus/${cred.user.uid}`));
        const status = statusSnap.val();

        if (!status || status.status !== 'paired') {
            console.error('❌ Not paired with bot');
            process.exit(1);
        }

        const gameId = status.gameId;
        console.log(`\n✅ Paired with bot! Game ID: ${gameId}`);

        // Check game state
        const gameSnap = await get(ref(db, `games/${gameId}`));
        const game = gameSnap.val();

        console.log('\n📊 Game State:');
        console.log('  Players:', Object.keys(game.players));
        console.log('  Is Bot Game:', game.isBotGame);
        console.log('  Turn:', game.turn);

        if (!game.isBotGame) {
            console.error('❌ Game not marked as bot game');
            process.exit(1);
        }

        // Check gold deduction
        const afterJoinGoldSnap = await get(ref(db, `users/${cred.user.uid}/gold`));
        const afterJoinGold = afterJoinGoldSnap.val();
        console.log(`\n💰 Gold after joining: ${afterJoinGold}`);

        if (afterJoinGold !== initialGold - 100) {
            console.error(`❌ Gold not deducted correctly. Expected ${initialGold - 100}, got ${afterJoinGold}`);
            process.exit(1);
        }

        console.log('✅ Entry fee deducted correctly');

        // Listen for bot move
        console.log('\n🤖 Waiting for bot to make a move...');

        const unsubscribe = onValue(ref(db, `games/${gameId}/lastMove`), (snapshot) => {
            const lastMove = snapshot.val();
            if (lastMove && lastMove.uid === 'BOT_PLAYER') {
                console.log('\n🤖 Bot made a move!');
                console.log('  Token:', lastMove.tokenIndex);
                console.log('  From:', lastMove.from, '→ To:', lastMove.to);
                unsubscribe();

                console.log('\n✅ All bot tests passed!');
                process.exit(0);
            }
        });

        // Timeout after 120 seconds
        setTimeout(() => {
            console.error('❌ Bot did not make a move');
            process.exit(1);
        }, 120000);

    } catch (e) {
        console.error('❌ Error:', e);
        process.exit(1);
    }
}

testBotPairing();
