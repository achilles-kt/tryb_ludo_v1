import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'board_layout.dart';
import 'ludo_game.dart';

class TokenComponent extends PositionComponent with TapCallbacks {
  final String ownerUid;
  final int tokenIndex;
  final PlayerColor color;

  int _logicalPos; // -1 = yard, 0..51 = main, 52..57 = home

  TokenComponent({
    required this.ownerUid,
    required this.tokenIndex,
    required this.color,
    required int initialPositionIndex,
  })  : _logicalPos = initialPositionIndex,
        super(size: Vector2.all(18));

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    _updateWorldPosition();
  }

  void updatePositionIndex(int newIndex) {
    _logicalPos = newIndex;
    _updateWorldPosition();
  }

  void _updateWorldPosition() {
    // Use tokenIndex for yard slot disambiguation
    final pos = BoardLayout.positionFor(
      color,
      _logicalPos,
      tokenIndexForYard: tokenIndex,
    );

    // Position is now relative to BoardComponent top-left (0,0)
    position = pos;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = _colorForPlayer(color)
      ..style = PaintingStyle.fill;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final center = Offset(size.x / 2, size.y / 2);

    canvas.drawCircle(center.translate(0, 2), size.x / 2, shadow);
    canvas.drawCircle(center, size.x / 2, paint);

    final border = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, size.x / 2, border);
  }

  Color _colorForPlayer(PlayerColor c) {
    switch (c) {
      case PlayerColor.red:
        return const Color(0xFFEF4444);
      case PlayerColor.green:
        return const Color(0xFF22C55E);
      case PlayerColor.yellow:
        return const Color(0xFFEAB308);
      case PlayerColor.blue:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final game = findGame() as LudoGame;
    game.onTokenTapped(this);
  }
}
