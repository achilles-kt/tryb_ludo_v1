import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'board_layout.dart';

class BoardComponent extends PositionComponent with HasGameRef<FlameGame> {
  // Callback to resolve color for a visual seat (0-3)
  final PlayerColor Function(int visualSeat)? colorResolver;

  BoardComponent({this.colorResolver})
      : super(size: Vector2(BoardLayout.boardSize, BoardLayout.boardSize));

  Color _getColorForSeat(int visualSeat) {
    if (colorResolver != null) {
      final pColor = colorResolver!(visualSeat);
      return _mapPlayerColorToFlutterColor(pColor);
    }
    // Fallback to static seat colors
    return switch (visualSeat) {
      0 => const Color(0xFFFF0033), // Red
      1 => const Color(0xFF00FF33), // Green
      2 => const Color(0xFFFFCC00), // Yellow
      3 => const Color(0xFF0066FF), // Blue
      _ => Colors.white,
    };
  }

  Color _mapPlayerColorToFlutterColor(PlayerColor c) {
    return switch (c) {
      PlayerColor.red => const Color(0xFFFF0033),
      PlayerColor.green => const Color(0xFF00FF33),
      PlayerColor.yellow => const Color(0xFFFFCC00),
      PlayerColor.blue => const Color(0xFF0066FF),
    };
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    // Fix: Hardcode position to center of the 340x340 world.
    // Do NOT use gameRef.size, as that changes with screen size and shifts the board.
    position = Vector2(BoardLayout.boardSize / 2, BoardLayout.boardSize / 2);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(16),
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

    // Config for Neon Bases
    final double basePadding = 4.0;
    final double cornerRadius = 24.0;
    final double slotRadius = cs * 0.35; // Size of token slot

    void drawNeonBase(int rowStart, int colStart, int visualSeat) {
      final color = _getColorForSeat(visualSeat);

      // 1. Calculate Base Rect
      final baseRect = Rect.fromLTWH(
        colStart * cs + basePadding,
        rowStart * cs + basePadding,
        (cs * 6) - (basePadding * 2),
        (cs * 6) - (basePadding * 2),
      );

      final baseRRect =
          RRect.fromRectAndRadius(baseRect, Radius.circular(cornerRadius));

      // 2. Neon Glow (Outer Blur)
      final glowPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0); // Neon Blur
      canvas.drawRRect(baseRRect, glowPaint);

      // 3. Solid Stroke (Core of Neon)
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(baseRRect, strokePaint);

      // 4. Dark Fill
      final fillPaint = Paint()
        ..color = const Color(0xFF1E1E24) // Premium Dark Grey
        ..style = PaintingStyle.fill;
      canvas.drawRRect(baseRRect, fillPaint);

      // 5. Draw 4 Token Slots (Yards)
      // We need to fetch the yard positions for this color from BoardLayout.
      // We can map visualSeat -> PlayerColor.
      PlayerColor pColor;
      switch (visualSeat) {
        case 0:
          pColor = PlayerColor.red;
          break;
        case 1:
          pColor = PlayerColor.green;
          break;
        case 2:
          pColor = PlayerColor.yellow;
          break;
        case 3:
          pColor = PlayerColor.blue;
          break;
        default:
          pColor = PlayerColor.red;
      }

      final yardPositions = BoardLayout.homeYard[pColor];
      if (yardPositions != null) {
        final slotPaint = Paint()
          ..color = const Color(0xFF15151A) // Darker than base
          ..style = PaintingStyle.fill;

        final slotRingPaint = Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (final pos in yardPositions) {
          // pos is already in World Coordinates (Vector2) from BoardLayout.cellCenter
          // But BoardLayout.cellCenter gives center of cell.
          // That matches perfectly.
          canvas.drawCircle(pos.toOffset(), slotRadius, slotPaint);
          canvas.drawCircle(pos.toOffset(), slotRadius, slotRingPaint);
        }
      }
    }

    drawNeonBase(9, 0, 0); // Bottom-Left (Red) - Row 9-14, Col 0-5
    drawNeonBase(0, 0, 1); // Top-Left (Green) - Row 0-5, Col 0-5
    drawNeonBase(0, 9, 2); // Top-Right (Yellow) - Row 0-5, Col 9-14
    drawNeonBase(9, 9, 3); // Bottom-Right (Blue) - Row 9-14, Col 9-14
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
      // Green (Top-Left, Seat 1) -> Row 7, Cols 1-5
      if (row == 7 && col >= 1 && col <= 5) {
        paint = Paint()
          ..color = _getColorForSeat(1).withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Blue (Bottom-Right, Seat 3) -> Row 7, Cols 9-13
      else if (row == 7 && col >= 9 && col <= 13) {
        paint = Paint()
          ..color = _getColorForSeat(3).withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Yellow (Top-Right, Seat 2) -> Rows 1-5, Col 7
      else if (col == 7 && row >= 1 && row <= 5) {
        paint = Paint()
          ..color = _getColorForSeat(2).withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }
      // Red (Bottom-Left, Seat 0) -> Rows 9-13, Col 7
      else if (col == 7 && row >= 9 && row <= 13) {
        paint = Paint()
          ..color = _getColorForSeat(0).withOpacity(0.2)
          ..style = PaintingStyle.fill;
      }

      final rect = Rect.fromLTWH(
        col * cs + 2, // Slightly more gap
        row * cs + 2,
        cs - 4,
        cs - 4,
      );
      final rrect = RRect.fromRectAndRadius(
          rect, const Radius.circular(6)); // More rounded
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
