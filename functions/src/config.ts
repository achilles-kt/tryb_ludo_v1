import * as admin from "firebase-admin";

// --------------------------------------------------------
// Default Configuration Values (Fallback)
// --------------------------------------------------------
const DEFAULTS = {
    global: {
        gemFee: 10,
        turnTimeoutSec: 15, // Standard turn time
        botTakeoverSec: 10, // Time before bot takes over
        gameTimeoutMin: 15,
        initialRewards: {
            gold: 5000,
            gems: 50
        }
    },
    modes: {
        "2p": {
            stake: 1000,
            queueTimeoutSec: 60,
            botWaitSec: 45
        },
        "4p_solo": {
            stake: 1000,
            queueTimeoutSec: 40,
            botWaitSec: 40
        },
        "4p_team": {
            stake: 1000,
            queueTimeoutSec: 40
        },
        "private": {
            stake: 1000,
            queueTimeoutSec: 0
        }
    }
};

// --------------------------------------------------------
// Interfaces
// --------------------------------------------------------

export interface GlobalConfig {
    gemFee: number;
    turnTimeoutSec: number;
    botTakeoverSec: number;
    gameTimeoutMin: number;
    initialRewards: {
        gold: number;
        gems: number;
    };
}

export interface ModeConfig {
    stake: number;
    queueTimeoutSec: number;
    botWaitSec?: number;
}

export interface AppConfig {
    global: GlobalConfig;
    modes: {
        "2p": ModeConfig;
        "4p_solo": ModeConfig;
        "4p_team": ModeConfig;
        "private": ModeConfig;
    };
}

// --------------------------------------------------------
// Get Configuration (Server Authority)
// --------------------------------------------------------
export async function getConfig(): Promise<AppConfig> {
    try {
        const snap = await admin.database().ref('config').get();
        if (snap.exists()) {
            const val = snap.val();

            // Deep merge logic or explicit mapping to ensure safety
            return {
                global: {
                    gemFee: Number(val.global?.gemFee) || DEFAULTS.global.gemFee,
                    turnTimeoutSec: Number(val.global?.turnTimeoutSec) || DEFAULTS.global.turnTimeoutSec,
                    botTakeoverSec: Number(val.global?.botTakeoverSec) || DEFAULTS.global.botTakeoverSec,
                    gameTimeoutMin: Number(val.global?.gameTimeoutMin) || DEFAULTS.global.gameTimeoutMin,
                    initialRewards: {
                        gold: Number(val.global?.initialRewards?.gold) || DEFAULTS.global.initialRewards.gold,
                        gems: Number(val.global?.initialRewards?.gems) || DEFAULTS.global.initialRewards.gems
                    }
                },
                modes: {
                    "2p": {
                        stake: Number(val.modes?.['2p']?.stake) || DEFAULTS.modes["2p"].stake,
                        queueTimeoutSec: Number(val.modes?.['2p']?.queueTimeoutSec) || DEFAULTS.modes["2p"].queueTimeoutSec,
                        botWaitSec: Number(val.modes?.['2p']?.botWaitSec) || DEFAULTS.modes["2p"].botWaitSec,
                    },
                    "4p_solo": {
                        stake: Number(val.modes?.['4p_solo']?.stake) || DEFAULTS.modes["4p_solo"].stake,
                        queueTimeoutSec: Number(val.modes?.['4p_solo']?.queueTimeoutSec) || DEFAULTS.modes["4p_solo"].queueTimeoutSec,
                        botWaitSec: Number(val.modes?.['4p_solo']?.botWaitSec) || DEFAULTS.modes["4p_solo"].botWaitSec,
                    },
                    "4p_team": {
                        stake: Number(val.modes?.['4p_team']?.stake) || DEFAULTS.modes["4p_team"].stake,
                        queueTimeoutSec: Number(val.modes?.['4p_team']?.queueTimeoutSec) || DEFAULTS.modes["4p_team"].queueTimeoutSec,
                    },
                    "private": {
                        stake: Number(val.modes?.['private']?.stake) || DEFAULTS.modes["private"].stake,
                        queueTimeoutSec: 0, // Not applicable
                    }
                }
            };
        }
    } catch (e) {
        console.error("Config fetch failed, using defaults:", e);
    }

    return DEFAULTS;
}

// Export constants for legacy support (if any files import them directly)
export const TURN_TIMEOUT_SEC = DEFAULTS.global.turnTimeoutSec;
export const BOT_TAKEOVER_SEC = DEFAULTS.global.botTakeoverSec;
export const GAME_TIMEOUT_MIN = DEFAULTS.global.gameTimeoutMin;
export const INITIAL_GOLD = 5000;
