import { applyMoveAndReturnState } from "./logic";

export type BotAction =
    | { type: "roll" }
    | { type: "move"; tokenIndex: number }
    | { type: "skip" }
    | { type: "wait" }; // For when it's not the right phase or time

export function getBotDecision(game: any, botUid: string): BotAction {
    if (!game || game.turn !== botUid) {
        console.log(`🤖 BOT_DECISION: Not my turn (${game?.turn} vs ${botUid})`);
        return { type: "wait" };
    }

    const phase = game.turnPhase || "waitingRoll";

    // 1. Roll Dice
    if (phase === "waitingRoll" || phase === "rolling") {
        return { type: "roll" };
    }

    // 2. Move Token
    if (phase === "waitingMove" || phase === "moving" || phase === "rollingAnim") {
        // Note: rollingAnim is included as a failsafe, treating it as waitingMove if we have a diceValue
        // But strictly speaking, we should wait for animation. 
        // However, if we are here via autoPlayTurns (timeout), we should act.

        const diceValue = game.diceValue;
        if (!diceValue) {
            // Should not happen in waitingMove, but if so, maybe we need to roll?
            // Or just wait.
            return { type: "wait" };
        }

        // Find valid moves
        const validTokens: number[] = [];
        for (let i = 0; i < 4; i++) {
            try {
                applyMoveAndReturnState(game, botUid, i, diceValue);
                validTokens.push(i);
            } catch (e) {
                // Invalid
            }
        }

        if (validTokens.length === 0) {
            return { type: "skip" };
        }

        // Random strategy (as requested)
        const tokenIndex = validTokens[Math.floor(Math.random() * validTokens.length)];
        return { type: "move", tokenIndex };
    }

    console.log(`🤖 BOT_DECISION: Waiting (Phase: ${phase})`);
    return { type: "wait" };
}
