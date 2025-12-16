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

        // 1. Construct Table Data
        const tablePlayers: any = {};
        const gamePlayers: any = {};
        const initialBoard: any = {};

        // Default Colors/Seats for 2P/4P
        const defaultColors = mode === 'team'
            ? ['red', 'green', 'yellow', 'blue'] // Team seats 0,1,2,3
            : ['red', 'yellow']; // 2P seats 0,2 usually

        players.forEach(p => {
            // Determine Color
            let color = "red";
            if (p.seat === 2) color = "yellow";
            if (p.seat === 1) color = "green";
            if (p.seat === 3) color = "blue";

            tablePlayers[p.uid] = {
                seat: p.seat,
                name: p.name || `Player ${p.seat + 1}`,
                color: color,
                ...(p.team ? { team: p.team } : {})
            };

            gamePlayers[p.uid] = {
                seat: p.seat,
                color: color,
                ...(p.team ? { team: p.team } : {})
            };

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

        // 2. Construct Game Data
        const gameData = {
            tableId,
            mode,
            stake,
            players: gamePlayers,
            board: initialBoard,
            turn: players[0].uid, // Start with first player in list (usually P1)
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
            if (p.uid.startsWith("bot_")) continue; // Skip bots

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
        console.log(`🏗️ GAME_BUILDER: Created ${mode} game ${gameId} for ${players.map(p => p.uid).join(', ')}`);

        return { gameId, tableId };
    }
};
