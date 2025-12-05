import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'board_layout.dart';

class BoardComponent extends PositionComponent with HasGameRef<FlameGame> {
  BoardComponent()
      : super(size: Vector2(BoardLayout.boardSize, BoardLayout.boardSize));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    position = gameRef.size / 2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(24),
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF141418)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rect, borderPaint);

    _drawHomes(canvas);
    _drawPaths(canvas);
    _drawSafeStars(canvas);
  }

  void _drawHomes(Canvas canvas) {
    final cs = BoardLayout.cellSize;

    void homeBlock(int rowStart, int colStart, Color color) {
      final paint = Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final rect = Rect.fromLTWH(
        colStart * cs,
        rowStart * cs,
        cs * 4,
        cs * 4,
      );
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
    }

    homeBlock(11, 0, Colors.red); // bottom-left
    homeBlock(0, 0, Colors.green); // top-left
    homeBlock(0, 11, Colors.yellow); // top-right
    homeBlock(11, 11, Colors.blue); // bottom-right
  }

  void _drawPaths(Canvas canvas) {
    final cs = BoardLayout.cellSize;
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    // Draw horizontal mid path
    canvas.drawRect(
      Rect.fromLTWH(5 * cs, 7 * cs, cs * 5, cs),
      pathPaint,
    );

    // Draw vertical mid path
    canvas.drawRect(
      Rect.fromLTWH(7 * cs, 5 * cs, cs, cs * 5),
      pathPaint,
    );

    // Center
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(6 * cs, 6 * cs, cs * 3, cs * 3),
      centerPaint,
    );
  }

  void _drawSafeStars(Canvas canvas) {
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final safeCells = <Offset>[
      // Example safe cells – dev to align with your exact grid spec
      BoardLayout.cellCenter(2, 2).toOffset(),
      BoardLayout.cellCenter(2, 12).toOffset(),
      BoardLayout.cellCenter(12, 2).toOffset(),
      BoardLayout.cellCenter(12, 12).toOffset(),
    ];

    for (final c in safeCells) {
      canvas.drawCircle(c, 4, starPaint);
    }
  }
}
