import { SAFE_INDICES, FINAL_HOME_INDEX, ApplyMoveResult } from './core';
import { areTeammates, getTeammateUid } from './team';

/**
 * Pure Ludo move logic.
 * Does NOT:
 *  - roll dice
 *  - change turn, consecutiveSixes, deadlines
 *
 * It ONLY:
 *  - validates the move
 *  - updates the board
 *  - handles captures
 *  - reports win + extraTurn flags
 *
 * Positions encoding per player:
 *  -1      = base (yard)
 *  0..51   = outer track
 *  52..57  = home column, 57 = final home
 */
export function applyMoveAndReturnState(
    game: any,
    uid: string,
    tokenIndex: number,
    diceValue: number,
): ApplyMoveResult {
    if (!game.board || !game.board[uid]) {
        throw new Error("Board for player not found.");
    }

    const myBoard: number[] = [...game.board[uid]]; // copy
    if (tokenIndex < 0 || tokenIndex > 3) {
        throw new Error("Invalid token index.");
    }

    const currentPos = myBoard[tokenIndex];
    if (typeof currentPos !== "number") {
        throw new Error("Invalid current position.");
    }

    if (diceValue < 1 || diceValue > 6) {
        throw new Error("Invalid dice value.");
    }

    // 1) Compute target position and validate according to encoding
    const target = computeTargetPosition(currentPos, diceValue);
    if (target === null) {
        throw new Error("Illegal move with this token and dice.");
    }

    // 2) Apply captures if target is on outer track
    const captures: { uid: string; tokenIndex: number }[] = [];
    const newBoard: { [userId: string]: number[] } = {};

    // Start with a shallow copy of all boards
    Object.keys(game.board).forEach((id) => {
        newBoard[id] = [...game.board[id]];
    });

    // If moving onto outer track cell, handle capture
    if (target >= 0 && target <= 51) {
        if (SAFE_INDICES.has(target)) {
            console.log(`🛡️ SAFE SPOT: ${uid} landed on ${target} (Safe). No captures.`);
        } else {
            for (const otherUid of Object.keys(newBoard)) {
                if (otherUid === uid) continue;

                // We need to convert the other player's position to OUR coordinate system to check for collision?
                // OR, the board encoding is relative to each player, so we need a way to map between them.
                // Wait, the user request said: "Captures: Landing on enemy on non-safe tile sends them back to home."
                // And "Board encoding is per player, relative".
                // This implies we need a way to convert between relative coordinates to check for overlaps.

                // Standard Ludo board: 52 cells global track.
                // Player 0 starts at global 0.
                // Player 1 starts at global 13.
                // Player 2 starts at global 26.
                // Player 3 starts at global 39.

                // Relative 0 for P0 is Global 0.
                // Relative 0 for P1 is Global 13.

                // To check capture, we must convert both to global coordinates.
                // Let's assume we have seat information in `game.players`.

                const mySeat = game.players[uid]?.seat ?? 0;
                const otherSeat = game.players[otherUid]?.seat ?? 0;

                const myGlobal = toGlobal(target, mySeat);

                for (let i = 0; i < newBoard[otherUid].length; i++) {
                    const otherPos = newBoard[otherUid][i];
                    if (otherPos >= 0 && otherPos <= 51) { // Only check if on outer track
                        const otherGlobal = toGlobal(otherPos, otherSeat);
                        if (myGlobal === otherGlobal) {
                            // Capture!
                            // [TEAM MODE] Check Friendly Fire
                            if (game.mode === 'team' && areTeammates(uid, otherUid, game)) {
                                console.log(`🤝 FRIENDLY: ${uid} landed on teammate ${otherUid} at ${otherGlobal}. Stacking.`);
                                continue;
                            }

                            newBoard[otherUid][i] = -1;
                            captures.push({ uid: otherUid, tokenIndex: i });
                        }
                    }
                }
            }
        }
    }


    // 3) Move our token
    newBoard[uid][tokenIndex] = target;

    // 4) Check win condition
    let hasWon = false;
    if (game.mode === 'team') {
        const teammateUid = getTeammateUid(uid, game);
        const myHome = newBoard[uid].every(p => p === FINAL_HOME_INDEX);
        const mateHome = teammateUid ? newBoard[teammateUid].every(p => p === FINAL_HOME_INDEX) : false;
        hasWon = myHome && mateHome;
    } else {
        // Standard 2P
        hasWon = newBoard[uid].every((pos) => pos === FINAL_HOME_INDEX);
    }

    // 5) Extra turn logic
    const extraTurn = diceValue === 6;

    const updatedGame: any = {
        board: newBoard,
    };

    if (hasWon) {
        updatedGame.state = "completed";
        updatedGame.winnerUid = uid; // For team mode, this indicates the 'finishing' player, logic downstream handles team win
        if (game.mode === 'team') {
            // Mark team as winner? Usually winnerUid is enough, but maybe winnerTeamId
        }
    }

    return {
        updatedGame,
        hasWon,
        extraTurn,
        captures,
    };
}

/**
 * Computes the new position based on current position & dice.
 * Returns `null` if the move is illegal.
 */
function computeTargetPosition(
    currentPos: number,
    diceValue: number,
): number | null {
    // Token in base (yard)
    if (currentPos === -1) {
        // Can only leave base on 6
        if (diceValue !== 6) {
            return null; // illegal
        }
        return 0; // entry square
    }

    // Token on track or in home column
    const target = currentPos + diceValue;

    // Cannot overshoot final home
    if (target > FINAL_HOME_INDEX) {
        return null;
    }

    return target;
}

function toGlobal(relativePos: number, seat: number): number {
    // 4 players, 13 steps apart.
    // Seat 0: offset 0
    // Seat 1: offset 13
    // Seat 2: offset 26
    // Seat 3: offset 39
    // Global track is 0..51.
    const offset = seat * 13;
    return (relativePos + offset) % 52;
}
