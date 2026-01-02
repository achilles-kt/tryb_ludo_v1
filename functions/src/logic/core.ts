export const SAFE_INDICES = new Set<number>([
    0, 8, 13, 21, 26, 34, 39, 47,
]);

export const FINAL_HOME_INDEX = 57;

export interface ApplyMoveResult {
    updatedGame: any;
    hasWon: boolean;
    extraTurn: boolean;
    captures: { uid: string; tokenIndex: number }[];
}
