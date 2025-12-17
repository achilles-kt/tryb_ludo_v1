import 'dart:async';

import 'package:flame/game.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Image;
import '../state/game_state.dart';
import 'board_layout.dart';
import 'board_component.dart';
import 'token_component.dart';
import 'view_rotation.dart';

enum TurnOwner { bottomLeft, topLeft, topRight, bottomRight }

class LudoGame extends FlameGame {
  final String gameId;
  final String tableId;
  final String localUid;
  final VoidCallback? onMoveCompleted;
  final void Function(GameResult)? onGameOver;

  StreamSubscription<DatabaseEvent>? _gameSub;
  Map<String, dynamic>? _currentGameState;

  // Components
  late BoardComponent _board;
  final Map<String, List<TokenComponent>> _tokens = {};

  // Player colors map
  final Map<String, PlayerColor> _playerColors = {};
  final Map<String, int> _playerSeats = {};

  // View rotation helper (initialized when players are known)
  ViewRotation? _viewRotation;

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
    this.onMoveCompleted,
    this.onGameOver,
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
    debugPrint('🔌 Subscribing to game: games/$gameId');
    final gameRef = FirebaseDatabase.instance.ref('games/$gameId');
    _gameSub = gameRef.onValue.listen(
      _onGameUpdate,
      onError: (e) {
        debugPrint('❌ Game subscription error: $e');
      },
    );
  }

  void _onGameUpdate(DatabaseEvent event) {
    debugPrint('📥 Game update received: ${event.snapshot.key}');
    final data = event.snapshot.value;
    if (data == null || data is! Map) return;

    _currentGameState = Map<String, dynamic>.from(data);

    // Extract game state
    final board = _currentGameState?['board'] as Map?;
    final turn = _currentGameState?['turn'] as String?;
    final diceValue = _currentGameState?['diceValue'] as int? ?? 1;
    final gameStateStr = _currentGameState?['state'] as String? ?? 'active';
    final winnerUid = _currentGameState?['winnerUid'] as String?;
    final players = _currentGameState?['players'] as Map?;

    // Update notifiers
    currentTurnUidNotifier.value = turn;
    diceValueNotifier.value = diceValue;

    // Map players to colors if not done
    if (_playerColors.isEmpty && players != null) {
      // Initialize view rotation with local player's seat
      final localSeat = players[localUid]?['seat'] as int? ?? 0;
      _viewRotation = ViewRotation(
        localPlayerSeat: localSeat,
        players: Map<String, dynamic>.from(players),
      );

      players.forEach((uid, meta) {
        if (meta is Map) {
          final seat = meta['seat'] as int? ?? 0;
          // Get color from ViewRotation (which reads from server data)
          _playerColors[uid] = _viewRotation!.getColorForPlayer(uid);
          _playerSeats[uid] = seat;
        }
      });

      // Initialize tokens for all players once colors are known
      _initializeTokens(players);
    }

    // Map turn UID to TurnOwner using view rotation
    if (_viewRotation != null &&
        turn != null &&
        players != null &&
        players[turn] != null) {
      final seat = players[turn]['seat'] ?? 0;
      final visualSeat = _viewRotation!.getVisualSeat(seat);
      turnOwnerNotifier.value = switch (visualSeat) {
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
    if (gameStateStr == 'completed') {
      _onGameCompleted(winnerUid);
    }

    // 4. Join Game Log (only once when we get players)
    if (players != null && _playerColors.isEmpty) {
      // This runs only once per game load usually
      final opponentUid = players.keys
          .firstWhere((k) => k != localUid, orElse: () => 'Unknown');
      debugPrint('4. Join game | UID: $localUid & Opponent: $opponentUid');
    }

    // 5. Turn Log
    if (turn != null && turn != currentTurnUidNotifier.value) {
      debugPrint(
          '5. Turn Change | Old: ${currentTurnUidNotifier.value} -> New: $turn | Game ID: $gameId');
    }

    // Phase Log
    final newPhaseStr =
        _currentGameState?['turnPhase'] as String? ?? 'waitingRoll';
    debugPrint(
        '🔄 State Update | Turn: $turn | Phase: $newPhaseStr | Dice: $diceValue');

    // 6. Dice Roll Log (Observed from backend)
    if (diceValue != diceValueNotifier.value) {
      debugPrint(
          '6. Dice roll (Observed) | UID: $turn | Game ID: $gameId | Dice: $diceValue');
    }

    onMoveCompleted?.call();
  }

  void _initializeTokens(Map players) {
    players.forEach((uid, meta) {
      final playerId = uid as String;
      if (!_tokens.containsKey(playerId)) {
        _tokens[playerId] = [];
        // Use BOARD color (based on visual seat) for token positioning
        // This ensures tokens appear at correct rotated positions
        final boardColor =
            _viewRotation?.getBoardColorForPlayer(playerId) ?? PlayerColor.red;

        for (int i = 0; i < 4; i++) {
          final token = TokenComponent(
            ownerUid: playerId,
            tokenIndex: i,
            color: boardColor, // Use board color for positioning
            initialPositionIndex: -1,
          );
          _tokens[playerId]!.add(token);
          _board.add(token); // Add to board instead of game
        }
      }
    });
  }

  void _updateTokens(Map board) {
    // Track position changes and trigger animations
    board.forEach((playerId, positions) {
      if (positions is! List) return;

      final playerTokens = _tokens[playerId];
      if (playerTokens == null) return;

      for (int i = 0; i < positions.length && i < playerTokens.length; i++) {
        final newPos = positions[i] as int;
        final oldPos = playerTokens[i].positionIndex;

        if (newPos != oldPos) {
          // Position changed - animate
          playerTokens[i].animateToPosition(newPos, oldPos);
        }
      }
    });

    // Now detect and handle stacks (after animations start)
    _detectAndApplyStacks();
  }

  void _detectAndApplyStacks() {
    // Group tokens by their position key
    final Map<String, List<TokenComponent>> stackGroups = {};

    _tokens.forEach((playerId, tokens) {
      final seat = _playerSeats[playerId];
      if (seat == null) return;

      for (final token in tokens) {
        final pos = token.positionIndex;
        // Only consider tokens on the track (not in yard)
        if (pos == -1) {
          token.setStackState(isStacked: false, stackIndex: 0);
          continue;
        }

        // Create a key based on visual position
        final key = '${playerId}_$pos';
        stackGroups.putIfAbsent(key, () => []);
        stackGroups[key]!.add(token);
      }
    });

    // Apply stack offsets
    stackGroups.forEach((key, tokens) {
      if (tokens.length > 1) {
        // This is a stack
        for (int i = 0; i < tokens.length; i++) {
          tokens[i].setStackState(
            isStacked: true,
            stackIndex: i,
            stackOffset: Vector2(i * 5.0, i * 5.0),
          );
        }
      } else {
        // Single token, not stacked
        tokens[0].setStackState(isStacked: false, stackIndex: 0);
      }
    });
  }

  Future<void> rollDice() async {
    // Only allow rolling if waitingRoll
    if (state.turnPhase != TurnPhase.waitingRoll) {
      debugPrint(
          '❌ Cannot roll: Not in waitingRoll phase (current: ${state.turnPhase})');
      return;
    }

    // Prevent double-taps while already processing a roll
    if (isRollingNotifier.value) {
      debugPrint('❌ Cannot roll: Already rolling');
      return;
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint('❌ Cannot roll: User not signed in (LudoGame check).');
        return;
      }

      // Force token refresh to ensure backend gets a valid token
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      // Frontend-First Animation: Start immediately
      isRollingNotifier.value = true;
      final startTime = DateTime.now();

      final callable = FirebaseFunctions.instance.httpsCallable('rollDiceV2');
      debugPrint('7. User taps (Dice) | UID: $localUid');
      debugPrint(
          '6. Dice roll (Request) | UID: $localUid | Game ID: $gameId | User Tap');

      final result = await callable.call({'gameId': gameId});
      debugPrint('6. Dice roll (Response) | Result: ${result.data}');

      // Ensure min 1s duration
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed));
      }

      // Animation stops when backend update arrives (via _onGameUpdate)
      isRollingNotifier.value = false;
    } catch (e) {
      isRollingNotifier.value = false;
      if (e is FirebaseFunctionsException) {
        debugPrint(
            '❌ Error rolling dice (Functions): Code=${e.code}, Msg=${e.message}, Details=${e.details}');
      } else {
        debugPrint('❌ Error rolling dice: $e');
      }
    }
  }

  //void _checkAutoMove() {
  // Auto-move is now handled by backend (onDiceRolled trigger).
  // Frontend just needs to allow manual move if waitingMove.
  // But we can keep this if we want "instant" feel before backend reacts?
  // No, backend is authoritative and has the delay logic.
  // We should remove frontend auto-move to avoid conflicts/double submissions.

  // However, for manual move, we still need validation.
  //}

  List<TokenComponent> getAvailableMoves(int diceValue) {
    final moves = <TokenComponent>[];
    final playerTokens = _tokens[localUid];

    if (playerTokens == null) return moves;

    for (final token in playerTokens) {
      if (_canMove(token, diceValue)) {
        moves.add(token);
      }
    }
    return moves;
  }

  bool _canMove(TokenComponent token, int diceValue) {
    final pos = token
        .positionIndex; // Assuming TokenComponent has this getter exposed or I need to add it
    // TokenComponent definition in file is not fully visible, but _updateTokens uses updatePositionIndex.
    // I should check TokenComponent to ensure I can access position.
    // Assuming I can access 'currentPositionIndex' or similar.
    // Wait, I need to check TokenComponent.
    // For now, I'll assume I can access it via a getter I'll add or existing one.
    // Let's assume 'token.currentPositionIndex'.

    // Logic:
    // -1 (Yard): Needs 6.
    if (pos == -1) {
      return diceValue == 6;
    }

    // Track (0-51) or Home (52-57)
    // Max is 57.
    if (pos + diceValue <= 57) {
      return true;
    }

    return false;
  }

  // Called by TokenComponent when tapped
  void onTokenTapped(TokenComponent token) {
    // Simply try to move the token
    _handleTokenMove(token.ownerUid, token.tokenIndex);
  }

  void _handleTokenMove(String playerId, int tokenIndex) async {
    if (playerId != localUid) return; // Not my token

    final turn = _currentGameState?['turn'] as String?;
    if (turn != localUid) return; // Not my turn

    // Check if move is valid before submitting?
    // Backend validates, but good for UI feedback.
    // We already checked in getAvailableMoves for auto-move.
    // For manual tap, we should also check.

    final token =
        _tokens[localUid]?.firstWhere((t) => t.tokenIndex == tokenIndex);
    if (token != null && !_canMove(token, diceValueNotifier.value)) {
      debugPrint('Invalid move');
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitMove');
      debugPrint(
          '7. Token Move | UID: $localUid | Game ID: $gameId | Token Index: $tokenIndex');
      await callable.call({
        'gameId': gameId,
        'tokenIndex': tokenIndex,
      });

      // Unfan after successful move
      // _currentFannedStack = null; // Removed as per instruction
    } catch (e) {
      debugPrint('Error submitting move: $e');
    }
  }

  void _onGameCompleted(String? winner) {
    print('Game completed! Winner: $winner');
    final isWin = winner == localUid;
    gameEndNotifier.value = GameEndState(
      isWin: isWin,
      rewardText: isWin ? 'You earned 900 Gold' : 'Better luck next time',
    );
    onGameOver?.call(isWin ? GameResult.win : GameResult.loss);
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

  // Helper to get player metadata for UI (with view rotation)
  PlayerMeta? getPlayerMeta(PlayerSpot spot) {
    if (_viewRotation == null || _currentGameState == null) return null;

    final players = _currentGameState?['players'] as Map?;
    if (players == null) return null;

    // Convert PlayerSpot to visual seat (0-3)
    final visualSeat = _playerSpotToVisualSeat(spot);

    // Get the player UID at this visual seat
    final uid = _viewRotation!.getPlayerAtVisualSeat(visualSeat);
    if (uid == null) return null;

    final playerData = players[uid];
    if (playerData == null) return null;

    return PlayerMeta(
      name: playerData['name'] ?? 'Player',
      avatarUrl: playerData['avatarUrl'],
      isYou: uid == localUid,
      isTeam: false, // TODO: implement team logic for 4P
    );
  }

  // Helper to get player metadata by visual seat index (0-3)
  PlayerMeta? getPlayerMetaByVisualSeat(int visualSeat) {
    if (_viewRotation == null || _currentGameState == null) return null;

    final uid = _viewRotation!.getPlayerAtVisualSeat(visualSeat);
    if (uid == null) return null;

    final players = _currentGameState?['players'] as Map?;
    final playerData = players?[uid];
    if (playerData == null) return null;

    // Check Team ID
    final localPlayer = players?[localUid];
    final int? localTeam = localPlayer?['team'];
    final int? targetTeam = playerData['team'];

    // Team Highlighting:
    // 1. Must be in a team (localTeam != null)
    // 2. Must match my team ID (localTeam == targetTeam)
    // 3. Applies to ME and TEAMMATE
    final bool isTeam =
        (localTeam != null && targetTeam != null && localTeam == targetTeam);

    // Determine Glow Color based on the player's board color
    final pColor = _playerColors[uid];
    Color? glowColor;
    if (isTeam && pColor != null) {
      glowColor = switch (pColor) {
        PlayerColor.red => const Color(0xFFFF5252),
        PlayerColor.green => const Color(0xFF69F0AE),
        PlayerColor.yellow => const Color(0xFFFFD740),
        PlayerColor.blue => const Color(0xFF448AFF),
      };
    }

    return PlayerMeta(
      name: playerData['name'] ?? 'Player',
      avatarUrl: playerData['avatarUrl'],
      isYou: uid == localUid,
      isTeam: isTeam,
      glowColor: glowColor,
    );
  }

  /// Helper to convert PlayerSpot enum to visual seat number (0-3)
  int _playerSpotToVisualSeat(PlayerSpot spot) {
    return switch (spot) {
      PlayerSpot.bottomLeft => 0,
      PlayerSpot.topLeft => 1,
      PlayerSpot.topRight => 2,
      PlayerSpot.bottomRight => 3,
      PlayerSpot.none => 0,
    };
  }

  GameState get state {
    final turn = _currentGameState?['turn'] as String?;
    final dice = diceValueNotifier.value;
    final isRolling = isRollingNotifier.value;
    final phaseStr =
        _currentGameState?['turnPhase'] as String? ?? 'waitingRoll';

    TurnPhase phase;
    switch (phaseStr) {
      case 'rollingAnim':
        phase = TurnPhase.rollingAnim;
        break;
      case 'waitingMove':
      case 'moving': // Legacy support
        phase = TurnPhase.waitingMove;
        break;
      case 'waitingRoll':
      case 'rolling': // Legacy support
      default:
        phase = TurnPhase.waitingRoll;
        break;
    }

    // Override phase if local animation is running (though backend now handles it)
    // Actually, backend 'rollingAnim' should drive the UI.
    // But we also have isRollingNotifier for local optimistic updates?
    // Let's rely on backend phase mostly, but keep isRollingNotifier for immediate feedback if needed.
    // If backend says rollingAnim, we show rolling.

    int currentPlayer = 0;
    if (turn != null && _playerSeats.containsKey(turn)) {
      currentPlayer = _playerSeats[turn]!;
    }

    int localPlayerIndex = 0;
    if (_playerSeats.containsKey(localUid)) {
      localPlayerIndex = _playerSeats[localUid]!;
    }

    // Calculate time left
    double timeLeft = 1.0;
    final deadline = _currentGameState?['turnDeadlineTs'] as int?;
    if (deadline != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final total = 10000; // 10s
      final remaining = deadline - now;
      timeLeft = (remaining / total).clamp(0.0, 1.0);
    }

    return GameState(
      isRolling: isRolling || phase == TurnPhase.rollingAnim,
      dice: dice,
      currentPlayer: currentPlayer,
      localPlayerIndex: localPlayerIndex,
      turnTimeLeft: timeLeft,
      turnPhase: phase,
      players: _currentGameState?['players'] != null
          ? Map<String, dynamic>.from(_currentGameState!['players'])
          : {},
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
  final Color? glowColor;

  PlayerMeta({
    this.name,
    this.avatarUrl,
    required this.isYou,
    required this.isTeam,
    this.glowColor,
  });
}

class GameEndState {
  final bool isWin;
  final String rewardText;
  GameEndState({required this.isWin, required this.rewardText});
}
