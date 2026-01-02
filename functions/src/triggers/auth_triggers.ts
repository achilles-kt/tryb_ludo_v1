import * as functions from "firebase-functions";
import { db } from "../admin";
import { getConfig } from "../config";

const getRandomAvatar = () => `assets/avatars/a${Math.floor(Math.random() * 8) + 1}.png`;

// ---------------------------------------------
// 1. Auto-create user profile with starting gold
// ---------------------------------------------
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
    const uid = user.uid;
    console.log(`✅ USER_CREATED: User ${uid} being created...`);

    const userRef = db.ref(`users/${uid}`);
    const snap = await userRef.get();

    if (snap.exists()) {
        return null;
    }

    // Get Config
    const config = await getConfig();
    const rewards = config.global.initialRewards;

    const now = Date.now();
    const profile = {
        profile: {
            displayName: user.displayName || "New User",
            avatarUrl: user.photoURL || getRandomAvatar(),
            city: "",
            country: "India",
            createdAt: now,
            lastLoginAt: now,
        },
        wallet: {
            gold: rewards.gold,
            gems: rewards.gems,
            createdAt: now,
            updatedAt: now,
            totalEarned: 0,
        },
        stats: {
            gamesPlayed: 0,
            gamesWon: 0,
        },
        // We initialize the friend code asynchronously or lazy, but let's leave it for now.
    };

    await userRef.set(profile);
    console.log(`✅ Default profile created for ${uid}`);
    return null;
});

// ---------------------------------------------
// 2. Manual Bootstrap (Callable)
// ---------------------------------------------
export const bootstrapUser = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in.");
    }

    const uid = context.auth.uid;
    console.log(`🔨 BOOTSTRAP: Checking usage for ${uid}...`);

    const userRef = db.ref(`users/${uid}`);
    const snap = await userRef.get();

    if (snap.exists()) {
        console.log(`🔨 BOOTSTRAP: Profile already exists for ${uid}.`);
        return { success: true, message: "Profile exists." };
    }

    // Get Config
    const config = await getConfig();
    const rewards = config.global.initialRewards;

    const now = Date.now();
    const profile = {
        profile: {
            displayName: "New User",
            avatarUrl: context.auth.token.picture || getRandomAvatar(),
            city: "",
            country: "India",
            createdAt: now,
            lastLoginAt: now,
        },
        wallet: {
            gold: rewards.gold,
            gems: rewards.gems,
            createdAt: now,
            updatedAt: now,
            totalEarned: 0,
        },
        stats: {
            gamesPlayed: 0,
            gamesWon: 0,
        },
    };

    await userRef.set(profile);
    console.log(`✅ Manual profile created for ${uid}`);
    return { success: true, created: true };
});
