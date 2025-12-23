enum GameResult { win, loss }

enum TurnPhase { waitingRoll, rollingAnim, waitingMove }

class GameState {
  final bool isRolling;
  final int dice;
  final int currentPlayer; // 0-3
  final int localPlayerIndex; // 0-3
  final double turnTimeLeft; // 0.0 - 1.0 or seconds
  final int? turnDeadlineTs;
  final TurnPhase turnPhase;
  final Map<String, dynamic> players;

  GameState({
    required this.isRolling,
    required this.dice,
    required this.currentPlayer,
    required this.localPlayerIndex,
    required this.turnTimeLeft,
    required this.turnPhase,
    required this.players,
    this.turnDeadlineTs,
  });

  // Factory for empty/initial state
  factory GameState.initial() {
    return GameState(
      isRolling: false,
      dice: 1,
      currentPlayer: 0,
      localPlayerIndex: 0,
      turnTimeLeft: 1.0,
      turnPhase: TurnPhase.waitingRoll,
      players: const {},
    );
  }
}
