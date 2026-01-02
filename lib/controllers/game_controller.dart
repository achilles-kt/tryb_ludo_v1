import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/presence_service.dart';
import '../../services/chat_service.dart'; // ActivityService
import '../../state/game_state.dart';

/// Central Controller for Game Logic & State.
/// Decouples the "Game Engine" from the "Game View" (Flame).
class GameController extends ChangeNotifier {
  // -------------------------------------------------------
  // Configuration
  // -------------------------------------------------------
  String? _gameId;
  String? _localUid;

  StreamSubscription<DatabaseEvent>? _gameSub;

  // -------------------------------------------------------
  // State Notifiers (Observable by UI)
  // -------------------------------------------------------

  final ValueNotifier<int> diceValue = ValueNotifier<int>(1);
  final ValueNotifier<bool> isRolling = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentTurnUid = ValueNotifier<String?>(null);
  final ValueNotifier<String?> winnerUid = ValueNotifier<String?>(null); // NEW

  // Board State (Maps PlayerID -> List<int> positions)
  final ValueNotifier<Map> boardState = ValueNotifier<Map>({});

  // The aggregated snapshot of the game (for UI builds)
  final ValueNotifier<GameState> gameState =
      ValueNotifier<GameState>(GameState.initial());

  // Callbacks
  void Function(String? winnerUid)? onGameCompleted;

  // -------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------

  Future<void> init(String gameId, String localUid) async {
    _gameId = gameId;
    _localUid = localUid;
    debugPrint('🎮 GameController: Initializing for $gameId');

    // Presence: Set Playing
    PresenceService().setPlaying(gameId);

    // Subscribe to game state
    _gameSub = FirebaseDatabase.instance.ref('games/$gameId').onValue.listen(
      _onGameUpdate,
      onError: (e) {
        debugPrint('❌ GameController: Subscription error: $e');
      },
    );
  }

  @override
  void dispose() {
    // Presence: Set back to Online (Idle)
    PresenceService().setOnline();

    _gameSub?.cancel();
    diceValue.dispose();
    isRolling.dispose();
    currentTurnUid.dispose();
    gameState.dispose();
    boardState.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // Data Processing
  // -------------------------------------------------------

  void _onGameUpdate(DatabaseEvent event) {
    if (event.snapshot.value == null) return;
    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    _processGameState(data);
  }

  void _processGameState(Map<String, dynamic> data) {
    final stateStr = data['state'] as String? ?? 'active';
    final winnerUid = data['winnerUid'] as String?;

    // Check completion
    if (stateStr == 'completed') {
      // Notify completion only once?
      // View will handle "shown" state, we just dispatch the event.
      onGameCompleted?.call(winnerUid);
      // We can stop processing further updates if desired, or keep syncing for chat etc.
    }

    final board = data['board'] as Map?;
    final turn = data['turn'] as String?;
    final dice = data['diceValue'] as int? ?? 1;
    final players = data['players'] as Map?;
    final phaseStr = data['turnPhase'] as String? ?? 'waitingRoll';

    // Update Primitive Notifiers
    if (diceValue.value != dice) diceValue.value = dice;
    if (currentTurnUid.value != turn) currentTurnUid.value = turn;

    // Update Board
    if (board != null) {
      // Deep check or just notify? simpler to just notify.
      boardState.value = Map.from(board);
    }

    // Logic for Rolling Animation State
    // If backend phase is 'rollingAnim', we are rolling.
    // Optimistic local rolling is handled by UI calling setRolling(true) temp.
    final backendRolling = (phaseStr == 'rollingAnim');

    // Determine TurnPhase enum
    TurnPhase phase;
    switch (phaseStr) {
      case 'rollingAnim':
        phase = TurnPhase.rollingAnim;
        break;
      case 'waitingMove':
      case 'moving':
        phase = TurnPhase.waitingMove;
        break;
      case 'waitingRoll':
      case 'rolling':
      default:
        phase = TurnPhase.waitingRoll;
        break;
    }

    // Calculate details for GameState snapshot
    int currentPlayerSeat = -1; // Default to -1 (Invalid)
    int localPlayerSeat = -2; // Default to -2 (Invalid, different from above)

    if (players != null && turn != null) {
      final pData = players[turn];
      if (pData is Map) {
        currentPlayerSeat = pData['seat'] ?? -1;
      }
    }

    if (players != null && _localUid != null) {
      final localData = players[_localUid];
      if (localData is Map) {
        localPlayerSeat = localData['seat'] ?? -2;
      }
    }

    // Time Left Calculation
    double timeLeft = 1.0;
    final deadline = data['turnDeadlineTs'] as int?;
    if (deadline != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final total = 10000;
      final remaining = deadline - now;
      timeLeft = (remaining / total).clamp(0.0, 1.0);
    }

    // Update Aggregated GameState
    final newState = GameState(
      isRolling: isRolling.value || backendRolling, // Combined local + backend
      dice: dice,
      currentPlayer: currentPlayerSeat,
      localPlayerIndex: localPlayerSeat,
      turnTimeLeft: timeLeft,
      turnPhase: phase,
      turnDeadlineTs: deadline,
      players: players != null ? Map<String, dynamic>.from(players) : {},
    );

    gameState.value = newState;

    // Re-sync local isRolling if needed (if backend finished anim)
    if (!backendRolling && isRolling.value == true) {
      // Keep local true until specific timeout?
      // For now, let UI control setRolling(false) manually for animation completion.
    }
  }

  // -------------------------------------------------------
  // Actions (Called by UI or Network)
  // -------------------------------------------------------

  Future<void> rollDice() async {
    // Basic validation based on local state
    if (gameState.value.turnPhase != TurnPhase.waitingRoll) {
      debugPrint('❌ GameController: Cannot roll - Wrong phase');
      return;
    }
    if (isRolling.value) return;

    try {
      setRolling(true);
      final startTime = DateTime.now();

      final result = await FirebaseFunctions.instance
          .httpsCallable('rollDiceV2')
          .call({'gameId': _gameId});

      debugPrint('🎲 GameController: rolled ${result.data}');

      // Min duration 1s
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed));
      }

      // Optimistic Update: Assume we are now waiting to move.
      // Do this BEFORE setRolling(false) so the UI never sees a state where
      // rolling is done BUT phase is still waitingRoll.
      gameState.value = gameState.value.copyWith(
        turnPhase: TurnPhase.waitingMove,
        // We could also update dice value here if we wanted to be super optimistic,
        // but the animation usually hides the value until it stops.
      );

      setRolling(false);

      // Wait a bit for "Center Pause" effect if UI needs it (View logic?)
      // View listens to isRolling. value becomes false. View moves dice to profile.
    } catch (e) {
      setRolling(false);
      debugPrint('❌ GameController: Roll failed: $e');
    }
  }

  Future<void> submitMove(int tokenIndex) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('submitMove')
          .call({'gameId': _gameId, 'tokenIndex': tokenIndex});
      debugPrint('♟️ GameController: Move submitted for token $tokenIndex');
    } catch (e) {
      debugPrint('❌ GameController: Move failed: $e');
    }
  }

  Future<void> forfeitGame() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('forfeitGame')
          .call({'gameId': _gameId});
      debugPrint('🏳️ GameController: Forfeit sent successfully');
    } catch (e) {
      debugPrint('❌ GameController: Forfeit failed: $e');
    }
  }

  Future<void> logGameResult(
      String winnerUid, String winnerName, bool isWin) async {
    try {
      // Activity Stream: Log Game Result
      final allUids = gameState.value.players.keys.toList();
      final convId = ActivityService.instance.getCanonicalId(allUids);

      ActivityService.instance.sendMessageToConversation(
        convId: convId,
        text: "Game Finished. Winner: $winnerName 🏆",
        type: "game_result",
        payload: {
          "result": isWin ? "win" : "loss",
          "winnerUid": winnerUid,
          "gameId": _gameId
        },
      );
    } catch (e) {
      debugPrint("Error logging game result: $e");
    }
  }

  void setRolling(bool rolling) {
    if (isRolling.value != rolling) {
      isRolling.value = rolling;
      // Triggers partial update via _processGameState next cycle or immediate?
      // Just notify listeners of isRolling change.
      // GameState listener will pick it up on next rebuild.
    }
  }
}
