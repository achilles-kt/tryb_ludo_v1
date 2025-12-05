import 'dart:async';

import 'package:flame/game.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart' hide Image;
import 'board_layout.dart';
import 'board_component.dart';
import 'token_component.dart';

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

  // Player colors map
  final Map<String, PlayerColor> _playerColors = {};

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
    final players = _currentGameState?['players'] as Map?;

    // Update notifiers
    currentTurnUidNotifier.value = turn;
    diceValueNotifier.value = diceValue;

    // Map players to colors if not done
    if (_playerColors.isEmpty && players != null) {
      players.forEach((uid, meta) {
        if (meta is Map) {
          final seat = meta['seat'] as int? ?? 0;
          _playerColors[uid as String] = _colorForSeat(seat);
        }
      });

      // Initialize tokens for all players once colors are known
      _initializeTokens(players);
    }

    // Map turn UID to TurnOwner
    if (players != null && turn != null && players[turn] != null) {
      final seat = players[turn]['seat'] ?? 0;
      turnOwnerNotifier.value = switch (seat) {
        0 => TurnOwner.bottomLeft,
        1 => TurnOwner.topLeft,
        2 => TurnOwner.topRight,
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
  }

  PlayerColor _colorForSeat(int seat) {
    switch (seat) {
      case 0:
        return PlayerColor.red; // BL
      case 1:
        return PlayerColor.green; // TL
      case 2:
        return PlayerColor.yellow; // TR
      case 3:
        return PlayerColor.blue; // BR
      default:
        return PlayerColor.red;
    }
  }

  void _initializeTokens(Map players) {
    players.forEach((uid, meta) {
      final playerId = uid as String;
      if (!_tokens.containsKey(playerId)) {
        _tokens[playerId] = [];
        final color = _playerColors[playerId] ?? PlayerColor.red;

        for (int i = 0; i < 4; i++) {
          final token = TokenComponent(
            ownerUid: playerId,
            tokenIndex: i,
            color: color,
            initialPositionIndex: -1,
          );
          _tokens[playerId]!.add(token);
          _board.add(token); // Add to board instead of game
        }
      }
    });
  }

  void _updateTokens(Map board) {
    board.forEach((playerId, positions) {
      if (positions is! List) return;

      final playerTokens = _tokens[playerId];
      if (playerTokens == null) return;

      for (int i = 0; i < positions.length && i < playerTokens.length; i++) {
        final pos = positions[i] as int;
        playerTokens[i].updatePositionIndex(pos);
      }
    });
  }

  Future<void> rollDice() async {
    isRollingNotifier.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    final newVal = DateTime.now().microsecond % 6 + 1;
    diceValueNotifier.value = newVal;
    isRollingNotifier.value = false;
  }

  void _handleTokenTap(String playerId, int tokenIndex) async {
    if (playerId != localUid) return; // Not my token

    final turn = _currentGameState?['turn'] as String?;
    if (turn != localUid) return; // Not my turn

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

  // Called by TokenComponent when tapped
  void onTokenTapped(TokenComponent token) {
    _handleTokenTap(token.ownerUid, token.tokenIndex);
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
  PlayerMeta? getPlayerMeta(PlayerSpot spot) {
    // For 2P:
    // BL = Seat 0
    // TR = Seat 1
    // Others = null

    if (spot == PlayerSpot.bottomLeft) {
      // Seat 0
      return PlayerMeta(
        name: 'Player 1',
        isYou:
            true, // Assuming local user is always seat 0 for now (or mapped to it)
        isTeam: false,
      );
    } else if (spot == PlayerSpot.topRight) {
      // Seat 1
      return PlayerMeta(
        name: 'Player 2',
        isYou: false,
        isTeam: false,
      );
    }

    return null;
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
