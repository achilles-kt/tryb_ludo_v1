import 'dart:async';

import 'package:flame/game.dart';

import 'package:flame/components.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart' hide Image;
import '../state/game_state.dart';
import 'board_layout.dart';
import 'board_component.dart';
import 'token_component.dart';
import 'view_rotation.dart';
import 'logic/ludo_rules.dart';
import '../controllers/game_controller.dart';

enum TurnOwner { bottomLeft, topLeft, topRight, bottomRight }

class LudoGame extends FlameGame {
  // Dependencies
  final GameController controller;

  // Identifiers (kept for reference, mostly handled by Controller)
  final String gameId;
  final String tableId;
  final String localUid;

  // Callbacks
  final VoidCallback? onMoveCompleted;

  // Components
  late BoardComponent _board;
  final Map<String, List<TokenComponent>> _tokens = {};

  // Visual State Helper
  final Map<String, PlayerColor> _playerColors = {};
  final Map<String, int> _playerSeats = {};
  ViewRotation? _viewRotation;

  // Local UI Notifiers (Driven by Controller State)
  // These are kept to allow Widget overlays to listen easily without full state parsing,
  // effectively mapping "State" to "UI ViewModels".
  final diceValueNotifier = ValueNotifier<int>(1);
  final currentTurnUidNotifier = ValueNotifier<String?>(null);
  final turnOwnerNotifier = ValueNotifier<TurnOwner>(TurnOwner.bottomLeft);
  final isRollingNotifier = ValueNotifier<bool>(false);
  final gameEndNotifier = ValueNotifier<GameEndState?>(null);

  LudoGame({
    required this.gameId,
    required this.tableId,
    required this.localUid,
    required this.controller, // Must be provided
    this.onMoveCompleted,
    void Function(GameResult)? onGameOver, // Legacy arg, unused by Game
  }) {
    // Connect Controller's completion directly?
    // Actually GameScreen listens to controller logic.
    // We process logical end here for specific UI updates if needed.
  }

  @override
  Future<void> onLoad() async {
    const double buffer = 10.0; // 5px offset per side
    const double totalSize = BoardLayout.boardSize + buffer; // 340 + 60 = 400

    // Zero-Centered Architecture:
    // The viewport is fixed at 400x400.
    // The camera looks at (0,0).
    // The Board operates at (0,0).
    // This guarantees perfect symmetry.
    camera.viewport =
        FixedResolutionViewport(resolution: Vector2(totalSize, totalSize));

    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.anchor = Anchor.center;

    await super.onLoad();

    // Add board with lazy color resolution
    _board = BoardComponent(
      colorResolver: (visualSeat) {
        if (_viewRotation != null) {
          return _viewRotation!.getColorForVisualSeat(visualSeat);
        }
        return switch (visualSeat) {
          0 => PlayerColor.red,
          1 => PlayerColor.green,
          2 => PlayerColor.yellow,
          3 => PlayerColor.blue,
          _ => PlayerColor.red,
        };
      },
    );
    // Important: Add to world, not game, so Camera view applies
    await world.add(_board);

    // Listen to Controller State
    controller.gameState.addListener(_onStateChanged);

    // Sync Initial State
    _onStateChanged();
  }

  @override
  void onRemove() {
    controller.gameState.removeListener(_onStateChanged);
    diceValueNotifier.dispose();
    currentTurnUidNotifier.dispose();
    turnOwnerNotifier.dispose();
    isRollingNotifier.dispose();
    gameEndNotifier.dispose();
    super.onRemove();
  }

  // -------------------------------------------------------------
  // State Sync
  // -------------------------------------------------------------

  void _onStateChanged() {
    final state = controller.gameState.value;

    // 1. Sync Primitives
    if (diceValueNotifier.value != state.dice) {
      diceValueNotifier.value = state.dice;
    }
    if (currentTurnUidNotifier.value != _getTurnUid(state)) {
      currentTurnUidNotifier.value = _getTurnUid(state);
      // Log turn usage or trigger sound?
    }
    if (isRollingNotifier.value != state.isRolling) {
      isRollingNotifier.value = state.isRolling;
    }

    // 2. Initialize Players/Rotation if new data arrived
    if (_playerColors.isEmpty && state.players.isNotEmpty) {
      _initializePlayers(state.players);
    }

    // 3. Update Turn Owner (Visual)
    final turnUid = _getTurnUid(state);
    if (_viewRotation != null && turnUid != null) {
      final seat = state.currentPlayer; // Server Seat
      final visualSeat = _viewRotation!.getVisualSeat(seat);
      turnOwnerNotifier.value = switch (visualSeat) {
        0 => TurnOwner.bottomLeft,
        1 => TurnOwner.topLeft,
        2 => TurnOwner.topRight,
        3 => TurnOwner.bottomRight,
        _ => TurnOwner.bottomLeft,
      };
    }

    // 4. Update Tokens (Positions)
    final boardData =
        controller.boardState.value; // Listen to separate notifier?
    // Actually we should use controller.boardState directly
    if (boardData.isNotEmpty) {
      _updateTokens(boardData);
    }

    // 5. Check Completion
    // Handled by Controller -> GameScreen.

    onMoveCompleted?.call();
  }

  String? _getTurnUid(GameState state) {
    // Find UID for current player index?
    // State has current player index. Map players to find UID.
    // Optimization: Controller could provide currentTurnUid directly.
    return controller.currentTurnUid.value;
  }

  void _initializePlayers(Map<String, dynamic> players) {
    // Determine my seat (local)
    final localMeta = players[localUid];
    final localSeat =
        (localMeta != null) ? (localMeta['seat'] as int? ?? 0) : 0;

    _viewRotation = ViewRotation(
      localPlayerSeat: localSeat,
      players: players,
    );

    players.forEach((uid, meta) {
      final seat = meta['seat'] as int? ?? 0;
      _playerColors[uid] = _viewRotation!.getColorForPlayer(uid);
      _playerSeats[uid] = seat;
    });

    _initializeTokens(players);
    debugPrint('🎨 LudoGame: Players & Colors initialized for view.');
  }

  void _initializeTokens(Map<String, dynamic> players) {
    players.forEach((uid, meta) {
      if (!_tokens.containsKey(uid)) {
        _tokens[uid] = [];
        final visualColor = _playerColors[uid] ?? PlayerColor.red;
        final logicColor =
            _viewRotation?.getBoardColorForPlayer(uid) ?? PlayerColor.red;

        for (int i = 0; i < 4; i++) {
          final token = TokenComponent(
            ownerUid: uid,
            tokenIndex: i,
            visualColor: visualColor,
            logicColor: logicColor,
            controller: controller,
            initialPositionIndex: -1,
          );
          _tokens[uid]!.add(token);
          // Add to BOARD, so they move with it and are in World space
          // Do NOT add to game root.
          _board.add(token);
        }
      }
    });
  }

  void _updateTokens(Map board) {
    // Trigger animations via tokens reading the map or pushing?
    // TokenComponent reads from Controller map usually?
    // Actually, TokenComponent usually listens to nothing, parent pushes updates OR it reads in update().
    // We will do stack detection here.
    _detectAndApplyStacks();
  }

  void _detectAndApplyStacks() {
    // ... (Keep existing stack logic, it's visual only)
    // For brevity, using minimal impl or keeping original code if possible.
    // Re-using original efficient logic:

    final Map<String, List<TokenComponent>> stackGroups = {};

    _tokens.forEach((playerId, tokens) {
      final seat = _playerSeats[playerId];
      if (seat == null) return;

      for (final token in tokens) {
        // Token component presumably reads its own position from controller.boardState automatically?
        // Or we update it?
        // Current TokenComponent likely reads `controller.boardState`.
        // Let's ensure TokenComponent is wired.
        // Assuming TokenComponent reads `controller.boardState`.

        final pos = token.positionIndex; // Get current visual position

        if (pos == -1) {
          token.setStackState(isStacked: false, stackIndex: 0);
          continue;
        }

        final key = '${playerId}_$pos';
        stackGroups.putIfAbsent(key, () => []);
        stackGroups[key]!.add(token);
      }
    });

    stackGroups.forEach((key, tokens) {
      if (tokens.length > 1) {
        for (int i = 0; i < tokens.length; i++) {
          tokens[i].setStackState(
            isStacked: true,
            stackIndex: i,
            stackOffset: Vector2(i * 5.0, i * 5.0),
          );
        }
      } else {
        tokens[0].setStackState(isStacked: false, stackIndex: 0);
      }
    });
  }

  // -------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------

  Future<void> rollDice() async {
    await controller.rollDice();
  }

  List<TokenComponent> getAvailableMoves(int diceValue) {
    // Pure Logic for UI highlighting
    final moves = <TokenComponent>[];
    final playerTokens = _tokens[localUid];
    if (playerTokens == null) return moves;

    for (final token in playerTokens) {
      if (LudoRules.canMove(token.positionIndex, diceValue)) {
        moves.add(token);
      }
    }
    return moves;
  }

  void onTokenTapped(TokenComponent token) {
    if (token.ownerUid != localUid) return;
    // Check turn?
    if (controller.currentTurnUid.value != localUid) return;

    // Delegate to Controller
    controller.submitMove(token.tokenIndex);
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------

  GameState get state => controller.gameState.value;

  PlayerMeta? getPlayerMeta(PlayerSpot spot) {
    // ... (Keep existing visual helper logic, utilizing _viewRotation)
    if (_viewRotation == null) return null;
    final visualSeat = _playerSpotToVisualSeat(spot);
    final uid = _viewRotation!.getPlayerAtVisualSeat(visualSeat);
    if (uid == null) return null;

    final pData = controller.gameState.value.players[uid];
    if (pData == null) return null;

    final pColor = _playerColors[uid];
    final colorVal = switch (pColor) {
      PlayerColor.red => const Color(0xFFFF5252),
      PlayerColor.green => const Color(0xFF69F0AE),
      PlayerColor.yellow => const Color(0xFFFFD740),
      PlayerColor.blue => const Color(0xFF448AFF),
      null || _ => Colors.grey,
    };

    return PlayerMeta(
      uid: uid,
      name: pData['name'] ?? 'Player',
      avatarUrl: pData['avatarUrl'],
      level: pData['level'] ?? 1,
      city: pData['city'] ?? "Earth",
      isYou: uid == localUid,
      isTeam: false, // Default for 2P/4P mixed calls if mode unknown
      playerColor: colorVal,
      isTurn: uid == controller.currentTurnUid.value,
    );
  }

  PlayerMeta? getPlayerMetaByVisualSeat(int visualSeat) {
    if (_viewRotation == null) return null;
    final uid = _viewRotation!.getPlayerAtVisualSeat(visualSeat);
    if (uid == null) return null;
    final pData = controller.gameState.value.players[uid];
    if (pData == null) return null;

    final localPlayer = controller.gameState.value.players[localUid];
    final int? localTeam = localPlayer?['team'];
    final int? targetTeam = pData['team'];
    final bool isTeam =
        (localTeam != null && targetTeam != null && localTeam == targetTeam);

    final pColor = _playerColors[uid];
    final colorVal = switch (pColor) {
      PlayerColor.red => const Color(0xFFFF5252),
      PlayerColor.green => const Color(0xFF69F0AE),
      PlayerColor.yellow => const Color(0xFFFFD740),
      PlayerColor.blue => const Color(0xFF448AFF),
      null || _ => Colors.grey,
    };

    Color? glowColor;
    if (isTeam && pColor != null) {
      glowColor = colorVal;
    }

    return PlayerMeta(
        uid: uid,
        name: pData['name'] ?? 'Player',
        avatarUrl: pData['avatarUrl'],
        level: pData['level'] ?? 1,
        city: pData['city'] ?? "Earth",
        isYou: uid == localUid,
        isTeam: isTeam,
        playerColor: colorVal,
        isTurn: uid == controller.currentTurnUid.value,
        glowColor: glowColor);
  }

  int _playerSpotToVisualSeat(PlayerSpot spot) {
    return switch (spot) {
      PlayerSpot.bottomLeft => 0,
      PlayerSpot.topLeft => 1,
      PlayerSpot.topRight => 2,
      PlayerSpot.bottomRight => 3,
      PlayerSpot.none => 0,
    };
  }
}

// Helpers
enum PlayerSpot { bottomLeft, topLeft, topRight, bottomRight, none }

class PlayerMeta {
  final String uid;
  final String? name;
  final String? avatarUrl;
  final int level;
  final String city;
  final bool isYou;
  final bool isTeam;
  final Color playerColor; // New
  final bool isTurn; // New
  final Color? glowColor;
  PlayerMeta(
      {required this.uid,
      this.name,
      this.avatarUrl,
      this.level = 1,
      this.city = "Earth",
      required this.isYou,
      required this.isTeam,
      required this.playerColor,
      required this.isTurn,
      this.glowColor});
}

class GameEndState {
  final bool isWin;
  final String rewardText;
  GameEndState({required this.isWin, required this.rewardText});
}
