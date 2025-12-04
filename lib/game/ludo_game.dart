import 'dart:async';

import 'package:flame/game.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart' hide Image;
import 'components/board_component.dart';
import 'components/token_component.dart';

enum TurnOwner { bottomLeft, topLeft, topRight, bottomRight }

class GameEndState {
  final bool isWin;
  final String rewardText;
  GameEndState({required this.isWin, required this.rewardText});
}

class LudoGame extends FlameGame {
  final String gameId;
  final String tableId;
  final String localUid;

  StreamSubscription<DatabaseEvent>? _gameSub;
  Map<String, dynamic>? _currentGameState;

  // Components
  late BoardComponent _board;
  final Map<String, List<TokenComponent>> _tokens = {};
  // late DiceComponent _dice; // Removed, logic moved to overlay

  // State Notifiers
  final diceValueNotifier = ValueNotifier<int>(1);
  final currentTurnUidNotifier = ValueNotifier<String?>(null);
  final turnOwnerNotifier = ValueNotifier<TurnOwner>(TurnOwner.bottomLeft);
  final isRollingNotifier = ValueNotifier<bool>(false);
  final gameEndNotifier = ValueNotifier<GameEndState?>(null);

  LudoGame({
    required this.gameId,
    required this.tableId,
    required this.localUid,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add board
    _board = BoardComponent();
    await add(_board);

    // Dice component removed from Flame game loop, handled by overlay
    // _dice = DiceComponent(position: Vector2(size.x / 2, size.y - 100));
    // await add(_dice);

    // Subscribe to game state
    _subscribeToGame();
  }

  void _subscribeToGame() {
    final gameRef = FirebaseDatabase.instance.ref('games/$gameId');
    _gameSub = gameRef.onValue.listen(_onGameUpdate);
  }

  void _onGameUpdate(DatabaseEvent event) {
    final data = event.snapshot.value;
    if (data == null || data is! Map) return;

    _currentGameState = Map<String, dynamic>.from(data);

    // Extract game state
    final board = _currentGameState?['board'] as Map?;
    final turn = _currentGameState?['turn'] as String?;
    final diceValue = _currentGameState?['diceValue'] as int? ?? 1;
    final state = _currentGameState?['state'] as String? ?? 'active';
    final winnerUid = _currentGameState?['winnerUid'] as String?;

    // Update notifiers
    currentTurnUidNotifier.value = turn;
    diceValueNotifier.value = diceValue;

    // Map turn UID to TurnOwner
    final players = _currentGameState?['players'] as Map?;
    if (players != null && turn != null && players[turn] != null) {
      final seat = players[turn]['seat'] ?? 0;
      turnOwnerNotifier.value = switch (seat) {
        0 => TurnOwner.bottomLeft,
        1 => TurnOwner
            .topRight, // Standard Ludo: 0=BL, 1=TR (opposite), 2=TL, 3=BR usually
        2 => TurnOwner.topLeft,
        3 => TurnOwner.bottomRight,
        _ => TurnOwner.bottomLeft,
      };
    }

    // Update tokens
    if (board != null) {
      _updateTokens(board);
    }

    // Check if game is completed
    if (state == 'completed') {
      _onGameCompleted(winnerUid);
    }

    // Update turn indicator
    final isMyTurn = turn == localUid;
    _highlightCurrentPlayer(isMyTurn);
  }

  void _updateTokens(Map board) {
    board.forEach((playerId, positions) {
      if (positions is! List) return;

      // Ensure tokens exist for this player
      if (!_tokens.containsKey(playerId)) {
        _tokens[playerId] = [];
        // TODO: Get color from player metadata/seat
        final color = playerId == localUid ? Colors.green : Colors.yellow;

        for (int i = 0; i < 4; i++) {
          final token = TokenComponent(
            playerId: playerId,
            tokenIndex: i,
            color: color,
          );
          _tokens[playerId]!.add(token);
          add(token);
        }
      }

      // Update positions
      for (int i = 0; i < positions.length && i < 4; i++) {
        final pos = positions[i] as int;
        _tokens[playerId]![i].moveToPosition(pos);
      }
    });
  }

  Future<void> rollDice() async {
    isRollingNotifier.value = true;

    // Simulate roll locally for UI feedback
    // In real implementation, this might be triggered by backend response
    // But for now we just trigger the backend call

    // Note: The actual move submission happens when a token is tapped.
    // If we want a separate "Roll Dice" step, we need a backend function for it.
    // For this implementation based on previous code, rolling is part of the move?
    // Actually, usually you roll first, then move.
    // But the previous code had `diceValue` generated in `_handleTokenTap`.

    // If we want to support "Roll then Move":
    // 1. Call backend to roll dice.
    // 2. Backend updates `diceValue` and state to `moving`.
    // 3. User taps token.

    // For now, to keep it simple and compatible with existing `submitMove` which takes `diceValue`:
    // We will just generate a random value here to show animation,
    // BUT `submitMove` in backend currently expects `diceValue` to be passed?
    // Let's check `submitMove` in index.ts.
    // It accepts `diceValue`.

    // So the flow is:
    // 1. User taps dice.
    // 2. UI animates.
    // 3. We store this "rolled" value locally?
    // OR we just wait for user to tap a token, and THEN we send the move with a new random value?

    // The previous `_handleTokenTap` generated a random value.
    // To support the UI "Roll Dice" button:
    // We should probably just animate the dice, and maybe store the value to be used when token is tapped?
    // Or, if the game rules allow "Roll" then "Move", we need to change the flow.

    // Let's stick to the existing flow for now:
    // Tapping dice just visualizes it?
    // The user request says: "When clicked / turn rolls, dice jumps to center, spins, then snaps back to owner"
    // And "await widget.game.rollDice(); // sets diceValueNotifier"

    // Let's implement `rollDice` to update the notifier so the user sees a value.
    // Then when they tap a token, we use THAT value?
    // But `_handleTokenTap` generates its own.

    // Let's update `rollDice` to generate a value and store it in `diceValueNotifier`.
    // And update `_handleTokenTap` to use that value if available, or generate one.

    await Future.delayed(
        const Duration(milliseconds: 500)); // Wait for animation
    final newVal = DateTime.now().microsecond % 6 + 1;
    diceValueNotifier.value = newVal;
    isRollingNotifier.value = false;
  }

  void _handleTokenTap(String playerId, int tokenIndex) async {
    if (playerId != localUid) return; // Not my token

    final turn = _currentGameState?['turn'] as String?;
    if (turn != localUid) return; // Not my turn

    // Use the value from the notifier if it was "rolled" recently?
    // Or just generate one here as before.
    // For safety/consistency with previous code:
    final diceValue = diceValueNotifier.value;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitMove');
      await callable.call({
        'gameId': gameId,
        'tokenIndex': tokenIndex,
        'diceValue': diceValue,
      });
    } catch (e) {
      print('Error submitting move: $e');
    }
  }

  void _highlightCurrentPlayer(bool isMyTurn) {
    // Update visual indication of whose turn it is
    _tokens.forEach((playerId, tokens) {
      final shouldHighlight = (playerId == localUid && isMyTurn);
      for (final token in tokens) {
        token.setHighlight(shouldHighlight);
      }
    });
  }

  // Called by TokenComponent when tapped
  void onTokenTapped(TokenComponent token) {
    _handleTokenTap(token.playerId, token.tokenIndex);
  }

  void _onGameCompleted(String? winner) {
    print('Game completed! Winner: $winner');
    gameEndNotifier.value = GameEndState(
      isWin: winner == localUid,
      rewardText:
          winner == localUid ? 'You earned 900 Gold' : 'Better luck next time',
    );
  }

  @override
  void onRemove() {
    _gameSub?.cancel();
    diceValueNotifier.dispose();
    currentTurnUidNotifier.dispose();
    turnOwnerNotifier.dispose();
    isRollingNotifier.dispose();
    gameEndNotifier.dispose();
    super.onRemove();
  }

  // Helper to get player metadata for UI
  PlayerMeta getPlayerMeta(PlayerSpot spot) {
    // TODO: Implement real mapping from `_currentGameState['players']`
    // For now, return mock/placeholder
    return PlayerMeta(
      name: 'Player',
      isYou: spot ==
          PlayerSpot.bottomLeft, // Assuming BL is always local user for now
      isTeam: false,
    );
  }
}

// Helper classes for UI
enum PlayerSpot { bottomLeft, topLeft, topRight, bottomRight, none }

class PlayerMeta {
  final String? name;
  final String? avatarUrl;
  final bool isYou;
  final bool isTeam;

  PlayerMeta(
      {this.name, this.avatarUrl, required this.isYou, required this.isTeam});
}
