import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'board_layout.dart';
import 'ludo_game.dart';
import '../controllers/game_controller.dart';

class TokenComponent extends PositionComponent with TapCallbacks {
  final String ownerUid;
  final int tokenIndex;
  final PlayerColor visualColor; // What it LOOKS like
  final PlayerColor logicColor; // Where it GOES
  final GameController controller;

  int _logicalPos; // -1 = yard, 0..51 = main, 52..57 = home

  // Stack state
  Vector2 _stackOffset = Vector2.zero();
  bool _isStacked = false;

  TokenComponent({
    required this.ownerUid,
    required this.tokenIndex,
    required this.visualColor,
    required this.logicColor,
    required this.controller,
    required int initialPositionIndex,
  })  : _logicalPos = initialPositionIndex,
        super(size: Vector2.all(18));

  int get positionIndex => _logicalPos;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    _updateWorldPosition();
    _setupPulseAnimation();

    // Subscribe to Board State
    controller.boardState.addListener(_onBoardStateChanged);
  }

  @override
  void onRemove() {
    controller.boardState.removeListener(_onBoardStateChanged);
    super.onRemove();
  }

  void _onBoardStateChanged() {
    final board = controller.boardState.value;
    final myPositions = board[ownerUid];

    if (myPositions is! List) return;
    if (tokenIndex >= myPositions.length) return;

    final newPos = myPositions[tokenIndex] as int;

    // Check if position actually changed
    if (newPos != _logicalPos) {
      // Animate!
      // Note: We need 'fromIndex' to decide animation direction.
      // Current _logicalPos IS the 'fromIndex'.
      animateToPosition(newPos, _logicalPos);
    }
  }

  void _setupPulseAnimation() {
    // Pulse animation will be triggered when stacked
    // We'll update the render method to apply scale based on _isStacked
  }

  void updatePositionIndex(int newIndex) {
    _logicalPos = newIndex;
    _updateWorldPosition();
  }

  void animateToPosition(int newIndex, int fromIndex) {
    if (fromIndex < 0 && newIndex >= 0) {
      // Exiting yard - instant placement
      _logicalPos = newIndex;
      _updateWorldPosition();
      return;
    }

    if (fromIndex >= 0 && newIndex > fromIndex) {
      // Get path positions
      final path = BoardLayout.getPathPositions(
        logicColor,
        fromIndex,
        newIndex,
        tokenIndexForYard: tokenIndex,
      );

      // Remove current position effects
      removeWhere((component) => component is MoveEffect);

      // Create hop sequence
      if (path.length > 1) {
        final effects = <Effect>[];
        for (int i = 1; i < path.length; i++) {
          effects.add(
            MoveEffect.to(
              path[i] + _stackOffset,
              EffectController(duration: 0.15),
            ),
          );
        }

        // Add effects sequentially
        add(SequenceEffect(effects, onComplete: () {
          _logicalPos = newIndex;
        }));
      } else {
        // Single position move
        _logicalPos = newIndex;
        _updateWorldPosition();
      }
    } else {
      // No animation needed
      _logicalPos = newIndex;
      _updateWorldPosition();
    }
  }

  void setStackState({
    required bool isStacked,
    required int stackIndex,
    Vector2? stackOffset,
  }) {
    _isStacked = isStacked;

    _stackOffset = stackOffset ?? Vector2.zero();
    _updateWorldPosition();
  }

  void _updateWorldPosition() {
    // Use tokenIndex for yard slot disambiguation
    final pos = BoardLayout.positionFor(
      logicColor,
      _logicalPos,
      tokenIndexForYard: tokenIndex,
    );

    // Position is now relative to BoardComponent top-left (0,0)
    // Apply stack offset
    position = pos + _stackOffset;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final radius = 7.0; // 14px width

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 4), radius, shadowPaint);

    // Pulsing glow for stacked tokens
    if (_isStacked) {
      final pulseTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final pulseScale = 1.0 + 0.15 * ((pulseTime % 1.0) * 2.0 - 1.0).abs();
      final glowRadius = radius * pulseScale;

      final pulseGlow = Paint()
        ..color = _colorForPlayer(visualColor).withOpacity(0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * pulseScale);
      canvas.drawCircle(center, glowRadius, pulseGlow);
    } else {
      // Normal Neon Glow
      final glowPaint = Paint()
        ..color = _colorForPlayer(visualColor).withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius, glowPaint);
    }

    // Body
    final paint = Paint()
      ..color = _colorForPlayer(visualColor)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Border
    final border = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, border);
  }

  Color _colorForPlayer(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return const Color(0xFFFF0033); // Neon Red
      case PlayerColor.green:
        return const Color(0xFF00FF33); // Neon Green
      case PlayerColor.yellow:
        return const Color(0xFFFFCC00); // Neon Yellow
      case PlayerColor.blue:
        return const Color(0xFF0066FF); // Neon Blue
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final game = findGame() as LudoGame;
    game.onTokenTapped(this);
  }
}
