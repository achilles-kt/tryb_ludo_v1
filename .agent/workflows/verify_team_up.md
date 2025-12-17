---
description: Verify Team Up Matchmaking Logic
---

# Verify Matchmaking Flows

You can check if the matchmaking logic (Team Up and 2P) is working correctly by running these scripts.

## 1. Test Team Up Flow (4 Players)
Simulate 4 players joining and forming a game:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"data": {"force": true}}' https://us-central1-tryb-ludo-v1.cloudfunctions.net/testTeamUpFlow
```

## 2. Test Team Up Bot Fallback (Timeout)
Simulate a player waiting too long and getting matched with bots:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"data": {"force": true}}' https://us-central1-tryb-ludo-v1.cloudfunctions.net/testTeamBotFallback
```

## 3. Test 2P Flow (2 Players)
Simulate 2 players joining and forming a 2P game:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"data": {"force": true}}' https://us-central1-tryb-ludo-v1.cloudfunctions.net/test2PFlow
```

## 4. Test Invite Flow
Simulate Guest sending invite to Host and Host accepting:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"data": {"force": true}}' https://us-central1-tryb-ludo-v1.cloudfunctions.net/testInviteFlow
```

## 5. Test ALL Flows (Combined)
Runs 2P, Team Up, Team Bot Fallback, and Invite flows in sequence:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"data": {"force": true}}' https://us-central1-tryb-ludo-v1.cloudfunctions.net/testAllFlows
```

**Success Criteria:**
- Output should contain `"results": {"2P": "PASSED", "TeamUp": "PASSED", "TeamBot": "PASSED", "Invite": "PASSED"}`.
