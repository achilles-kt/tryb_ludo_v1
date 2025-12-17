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
    final stepPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final safeStepPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Helper to draw a single cell
    void drawCell(int row, int col, {bool isSafe = false}) {
      Paint paint = isSafe ? safeStepPaint : stepPaint;

      // Check for home path colors
      // Green (Row 7, Cols 1-5)
      if (row == 7 && col >= 1 && col <= 5) {
        paint = Paint()
          ..color = Colors.green.withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Blue (Row 7, Cols 9-13)
      else if (row == 7 && col >= 9 && col <= 13) {
        paint = Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Yellow (Rows 1-5, Col 7)
      else if (col == 7 && row >= 1 && row <= 5) {
        paint = Paint()
          ..color = Colors.yellow.withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Red (Rows 9-13, Col 7)
      else if (col == 7 && row >= 9 && row <= 13) {
        paint = Paint()
          ..color = Colors.red.withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }

      final rect = Rect.fromLTWH(
        col * cs + 1, // +1 for gap/border effect
        row * cs + 1,
        cs - 2,
        cs - 2,
      );
      final rrect = RRect.fromRectAndRadius(
          rect, const Radius.circular(4)); // Rounded edges for cells too?
      canvas.drawRRect(rrect, paint);
    }

    // Left Arm (Rows 6-8, Cols 0-5)
    for (int r = 6; r <= 8; r++) {
      for (int c = 0; c <= 5; c++) {
        bool isSafe = (r == 8 && c == 1) || (r == 6 && c == 1);
        drawCell(r, c, isSafe: isSafe);
      }
    }

    // Right Arm (Rows 6-8, Cols 9-14)
    for (int r = 6; r <= 8; r++) {
      for (int c = 9; c <= 14; c++) {
        bool isSafe = (r == 6 && c == 13) || (r == 8 && c == 13);
        drawCell(r, c, isSafe: isSafe);
      }
    }

    // Top Arm (Rows 0-5, Cols 6-8)
    for (int r = 0; r <= 5; r++) {
      for (int c = 6; c <= 8; c++) {
        bool isSafe = (r == 1 && c == 8) || (r == 1 && c == 6);
        drawCell(r, c, isSafe: isSafe);
      }
    }

    // Bottom Arm (Rows 9-14, Cols 6-8)
    for (int r = 9; r <= 14; r++) {
      for (int c = 6; c <= 8; c++) {
        bool isSafe = (r == 13 && c == 6) || (r == 13 && c == 8);
        drawCell(r, c, isSafe: isSafe);
      }
    }

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
