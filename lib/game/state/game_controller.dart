import 'package:flutter/foundation.dart';
import '../../state/game_state.dart';

/// Central Controller for Game Logic & State.
/// Decouples the "Game Engine" from the "Game View" (Flame).
class GameController extends ChangeNotifier {
  // -------------------------------------------------------
  // State Notifiers (Observable by UI)
  // -------------------------------------------------------

  final ValueNotifier<int> diceValue = ValueNotifier<int>(1);
  final ValueNotifier<bool> isRolling = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentTurnUid = ValueNotifier<String?>(null);

  // Board State Stream (For Components)
  // Maps PlayerID -> List<int> (Token Positions)
  // Actually, ValueNotifier is better than Stream for "current state".
  // Components can just listen to it.
  final ValueNotifier<Map> boardState = ValueNotifier<Map>({});

  // The aggregated snapshot of the game (for UI builds)
  final ValueNotifier<GameState> gameState =
      ValueNotifier<GameState>(GameState.initial());

  // -------------------------------------------------------
  // Actions (Called by UI or Network)
  // -------------------------------------------------------

  void updateDice(int value) {
    if (diceValue.value != value) {
      diceValue.value = value;
      _refreshSnapshot();
    }
  }

  void setRolling(bool rolling) {
    if (isRolling.value != rolling) {
      isRolling.value = rolling;
      _refreshSnapshot();
    }
  }

  void setTurn(String? uid) {
    if (currentTurnUid.value != uid) {
      currentTurnUid.value = uid;
      // Note: Updating turn usually requires updating indices in GameState,
      // which we'll handle when we integrate full player data.
    }
  }

  void updateState(GameState newState) {
    gameState.value = newState;
  }

  void updateBoard(Map board) {
    // Only update if changed (deep check might be expensive, simpler check?)
    // For now, just notify.
    boardState.value = Map.from(board); // Clone to ensure notification
  }

  // Private helper to broadcast the full state change
  void _refreshSnapshot() {
    // In a real app, we'd copy the old state and specific fields.
    // For now, we notify listeners that something changed.
    notifyListeners();
  }

  @override
  void dispose() {
    diceValue.dispose();
    isRolling.dispose();
    currentTurnUid.dispose();
    gameState.dispose();
    boardState.dispose();
    super.dispose();
  }
}
