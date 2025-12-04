import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../ludo_game.dart';

class TokenComponent extends PositionComponent with TapCallbacks {
  final String playerId;
  final int tokenIndex;
  final Color color;

  int _currentGamePosition = -1;
  bool _isHighlighted = false;

  TokenComponent({
    required this.playerId,
    required this.tokenIndex,
    required this.color,
  }) : super(size: Vector2.all(30), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // No children needed, we render manually
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Glowing effect
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Add shadow/glow
    final path = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(size.x / 2, size.y / 2), radius: size.x / 2));
    canvas.drawShadow(path, color.withOpacity(0.5), 4, true);

    // Main circle
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);

    // Border
    final border = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, border);

    // Highlight if active
    if (_isHighlighted) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(size.x / 2, size.y / 2), size.x / 2, highlightPaint);
    }
  }

  void moveToPosition(int gamePosition) {
    if (_currentGamePosition == gamePosition) return;

    _currentGamePosition = gamePosition;

    // Get target position from board
    final targetPos = _calculateScreenPosition(gamePosition);

    // Animate movement
    add(MoveEffect.to(
      targetPos,
      EffectController(duration: 0.5, curve: Curves.easeInOut),
    ));
  }

  Vector2 _calculateScreenPosition(int gamePosition) {
    // TODO: Get from BoardComponent
    // For now, simple placeholder
    if (gamePosition < 0) {
      // Home
      return Vector2(50 + tokenIndex * 35, 450);
    } else if (gamePosition >= 57) {
      // Finish
      return Vector2(200, 300);
    } else {
      // Path - simple circular layout
      final angle = (gamePosition / 57.0) * 2 * 3.14159;
      final radius = 150.0;
      return Vector2(
        200 + radius * _cos(angle),
        300 + radius * _sin(angle),
      );
    }
  }

  double _cos(double x) {
    final normalized = x % (2 * 3.14159);
    return 1 -
        (normalized * normalized) / 2 +
        (normalized * normalized * normalized * normalized) / 24;
  }

  double _sin(double x) {
    final normalized = x % (2 * 3.14159);
    return normalized - (normalized * normalized * normalized) / 6;
  }

  void setHighlight(bool highlight) {
    if (_isHighlighted == highlight) return;

    _isHighlighted = highlight;

    // Add highlight effect
    if (highlight) {
      add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ));
    } else {
      add(ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.3, curve: Curves.easeOut),
      ));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_isHighlighted) {
      final game = findGame() as LudoGame?;
      game?.onTokenTapped(this);
    }
  }
}
