import * as functions from "firebase-functions";

// ------------------------------------------------------------------
// Exports from Modules
// ------------------------------------------------------------------

// Domain: Auth
export { onUserCreate, bootstrapUser } from "./triggers/auth_triggers";

// Domain: Game Logic & Controllers
export * from "./controllers/game";

// Domain: Game Triggers (Lifecycle, Dice, Bot)
export * from "./triggers/game_triggers";

// Domain: Queue & Matchmaking
export * from "./controllers/queue";
export * from "./triggers/matchmaking_triggers";

// Domain: Private Tables
export {
    createPrivateTable,
    joinPrivateGame
} from "./controllers/private_table";

// Domain: Invites
export {
    sendInvite,
    respondToInvite,
    cancelInvite
} from "./controllers/invites";
export { onInviteCreated } from "./triggers/invite_triggers";

// Domain: Social & Chat
export {
    handleInviteLink,
    checkDeferredLink
} from "./controllers/deep_links";

export {
    sendFriendRequest,
    respondToFriendRequest,
    removeFriend
} from "./controllers/social";

export {
    updateRecentPlayers
} from "./triggers/social_triggers";

export {
    verifySocialFlow
} from "./test_social";

export {
    registerPhone,
    syncContacts,
    backfillPhones
} from "./controllers/contacts";

export { maintainPhoneIndex } from "./triggers/contact_triggers";

export {
    verifyContactFlow
} from "./test_contacts";

export {
    startDM,
    sendMessage,
    startDMInternal,
    getDmId
} from "./controllers/chat";

export {
    verifyChatFlow
} from "./test_chat";

export {
    onMessageCreated,
    onFriendRelationshipUpdate
} from "./triggers/notification_triggers";

export { dailyMessageCleanup } from "./triggers/cleanup_triggers";

// Domain: Team Up / Solo Queue (Additional logic)
export {
    joinSoloQueue,
    joinTeamQueue,
    debugForce4PProcess
} from "./controllers/team_table";

// Domain: Simulation Tests
export {
    testTeamUpFlow,
    testTeamBotFallback,
    test2PFlow,
    testInviteFlow,
    testAllFlows
} from "./controllers/simulation";
