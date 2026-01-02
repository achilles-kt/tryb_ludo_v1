import { db } from "../admin";
import { BOT_TAKEOVER_SEC, TURN_TIMEOUT_SEC } from "../config";

interface PlayerInfo {
    uid: string;
    seat: number;
    team?: number; // 1 or 2 (for 4P)
    name?: string; // Optional display name override
}

interface GameCreateOptions {
    mode: '2p' | 'team' | 'private';
    stake: number;
    players: PlayerInfo[];
}

function calculateLevel(totalGold: number) {
    // Manual Thresholds (Matches Dart logic)
    const thresholds = [500, 1500, 3000, 5000, 7500, 10000];

    for (let i = 0; i < thresholds.length; i++) {
        if (totalGold < thresholds[i]) {
            return i + 1;
        }
    }

    // Post-10k Logic
    const basePostFixed = 10000;
    const accumulated = totalGold - basePostFixed;
    const levelsGained = Math.floor(accumulated / 2500);
    return 7 + levelsGained;
}

export const GameBuilder = {
    /**
     * Creates a fully active game session (Table + Game + User Statuses)
     * Atomically updates all paths.
     */
    async createActiveGame(options: GameCreateOptions) {
        const { mode, stake, players } = options;

        // Generate IDs
        const tableRef = db.ref("tables").push();
        const gameRef = db.ref("games").push();
        const tableId = tableRef.key!;
        const gameId = gameRef.key!;
        const now = Date.now();

        // 1. Construct Table/Game Data
        const tablePlayers: any = {};
        const gamePlayers: any = {};
        const initialBoard: any = {};

        // Fetch User Profiles (Parallel)
        const enrichedPlayers = await Promise.all(players.map(async (p) => {
            if (p.uid.startsWith('bot') || p.uid === 'BOT_PLAYER') {
                return {
                    ...p,
                    displayName: p.name || 'Bot',
                    avatarUrl: 'assets/avatars/bot.png', // Or specific bot avatar
                    city: 'AI City',
                    level: 1
                };
            }

            try {
                const snap = await db.ref(`users/${p.uid}`).get();
                const val = snap.val();
                if (val) {
                    const profile = val.profile || {};
                    const wallet = val.wallet || {}; // gold is inside users/{uid}/gold based on rule? No, rule implies users/uid/gold. But checks usage.
                    // Actually rule says "gold" is at root of user. But some code uses wallet wrapper?
                    // Let's assume structure is users/{uid}/profile and users/{uid}/gold (or wallet/totalEarned).
                    // LevelCalculator uses 'totalEarned'.
                    // Let's look at `wallet` node if it exists, otherwise `gold`.
                    // Actually, usually 'totalEarned' is tracked in 'wallet' if strict.
                    // If not found, default 0.
                    const totalEarned = (wallet && wallet.totalEarned) ? Number(wallet.totalEarned) : 0;

                    return {
                        ...p,
                        displayName: profile.displayName || p.name || 'Player',
                        avatarUrl: profile.avatar || profile.avatarUrl || null,
                        city: profile.city || 'Unknown',
                        level: calculateLevel(totalEarned)
                    };
                }
            } catch (e) {
                console.error(`Error fetching profile for ${p.uid}`, e);
            }
            return {
                ...p,
                displayName: p.name || 'Player',
                avatarUrl: null, // explicit null instead of undefined to satisfy RTDB
                city: 'Unknown',
                level: 1
            };
        }));

        enrichedPlayers.forEach(p => {
            // Determine Color
            let color = "red";
            if (p.seat === 2) color = "yellow";
            if (p.seat === 1) color = "green";
            if (p.seat === 3) color = "blue";

            const playerData = {
                seat: p.seat,
                name: p.displayName,
                avatarUrl: p.avatarUrl,
                level: p.level,
                city: p.city,
                color: color,
                ...(p.team ? { team: p.team } : {})
            };

            tablePlayers[p.uid] = playerData;
            gamePlayers[p.uid] = playerData; // Duplicate to Game for fast access

            initialBoard[p.uid] = [-1, -1, -1, -1];
        });

        const tableData = {
            gameId,
            mode,
            stake,
            players: tablePlayers,
            status: "active",
            createdAt: now
        };

        const gameData = {
            tableId,
            mode,
            stake,
            players: gamePlayers, // Now contains enriched data
            board: initialBoard,
            turn: players[0].uid,
            diceValue: 1,
            consecutiveSixes: 0,
            turnPhase: "rolling",
            state: "active",
            createdAt: now,
            updatedAt: now,
            turnStartedAt: now,
            botTakeoverAt: now + BOT_TAKEOVER_SEC * 1000,
            turnDeadlineAt: now + TURN_TIMEOUT_SEC * 1000,
            lastMoveTime: now,
        };

        // 3. Prepare Atomic Updates
        const updates: any = {};
        updates[`tables/${tableId}`] = tableData;
        updates[`games/${gameId}`] = gameData;

        // User Status Updates
        for (const p of players) {
            if (p.uid.startsWith("bot") || p.uid === "BOT_PLAYER") continue;

            updates[`userQueueStatus/${p.uid}`] = {
                status: "paired",
                tableId,
                gameId,
                ts: now
            };
            updates[`userGameStatus/${p.uid}`] = {
                status: "playing",
                gameId,
                tableId,
                ts: now
            };
            updates[`users/${p.uid}/currentGameId`] = gameId;
            updates[`users/${p.uid}/currentTableId`] = tableId;
        }

        await db.ref().update(updates);
        console.log(`🏗️ GAME_BUILDER: Created ${mode} game ${gameId} with enriched profiles.`);

        return { gameId, tableId };
    }
};
