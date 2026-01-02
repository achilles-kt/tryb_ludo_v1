export function areTeammates(uid1: string, uid2: string, game: any): boolean {
    const s1 = game.players[uid1]?.seat;
    const s2 = game.players[uid2]?.seat;
    // Team A: 0 & 2. Team B: 1 & 3.
    // Difference is 2.
    if (s1 === undefined || s2 === undefined) return false;
    return Math.abs(s1 - s2) === 2;
}

export function getTeammateUid(uid: string, game: any): string | null {
    const mySeat = game.players[uid]?.seat;
    if (mySeat === undefined) return null;
    const targetSeat = (mySeat + 2) % 4; // 0->2, 1->3, 2->0, 3->1
    return Object.keys(game.players).find(id => game.players[id]?.seat === targetSeat) || null;
}
