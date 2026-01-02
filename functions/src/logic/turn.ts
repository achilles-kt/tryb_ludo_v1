export function getNextPlayerUid(game: any, currentUid: string): string {
    const playerIds = Object.keys(game.players || {});
    // Robust Sort: ensure seat is a number
    playerIds.sort((a, b) => {
        const sa = Number(game.players[a]?.seat ?? 0);
        const sb = Number(game.players[b]?.seat ?? 0);
        return sa - sb;
    });

    const currentIndex = playerIds.indexOf(currentUid);
    if (currentIndex === -1) {
        console.warn(`getNextPlayerUid: Current UID ${currentUid} not found in players.`);
        return currentUid;
    }

    // Cycle through players starting from next
    for (let i = 1; i <= playerIds.length; i++) {
        const nextIndex = (currentIndex + i) % playerIds.length;
        const nextUid = playerIds[nextIndex];
        const player = game.players[nextUid];

        // Skip players who have left or are kicked
        // Treat undefined status as 'active' (safe default)
        const status = player.status || 'active';
        if (status === 'left' || status === 'kicked') {
            console.log(`⏭️ getNextPlayerUid: Skipping ${nextUid} (Status: ${status})`);
            continue;
        }

        return nextUid;
    }

    // fallback: If everyone else left, return current (or game over should handle)
    console.warn(`getNextPlayerUid: No other active players found. Returning current ${currentUid}`);
    return currentUid;
}
