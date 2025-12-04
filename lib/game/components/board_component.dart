import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BoardComponent extends PositionComponent {
  BoardComponent() : super(size: Vector2(340, 340));

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    position = Vector2(200, 300); // Approximate center
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Background: Rounded dark card
    final bgPaint = Paint()
      ..color = const Color(0xFF141418)
      ..style = PaintingStyle.fill;
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(24),
    );
    canvas.drawRRect(rect, bgPaint);

    // 2. Outer border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rect, borderPaint);

    // 3. Draw Ludo Grid (3x3 layout)
    // 15x15 conceptual grid
    final cellW = size.x / 15;
    final cellH = size.y / 15;

    // Helper to draw colored box
    void drawBox(int col, int row, int w, int h, Color color) {
      final r = Rect.fromLTWH(
        col * cellW,
        row * cellH,
        w * cellW,
        h * cellH,
      );
      canvas.drawRect(r, Paint()..color = color.withOpacity(0.2));
      canvas.drawRect(
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    // Home areas (6x6)
    drawBox(0, 0, 6, 6, Colors.red); // TL
    drawBox(9, 0, 6, 6, Colors.green); // TR
    drawBox(0, 9, 6, 6, Colors.blue); // BL
    drawBox(9, 9, 6, 6, Colors.yellow); // BR

    // Center (3x3)
    drawBox(6, 6, 3, 3, Colors.white);

    // Paths are remaining areas
    // Top path (vertical)
    drawBox(6, 0, 3, 6, Colors.white.withOpacity(0.1));
    // Bottom path (vertical)
    drawBox(6, 9, 3, 6, Colors.white.withOpacity(0.1));
    // Left path (horizontal)
    drawBox(0, 6, 6, 3, Colors.white.withOpacity(0.1));
    // Right path (horizontal)
    drawBox(9, 6, 6, 3, Colors.white.withOpacity(0.1));
  }

  // Helper to get screen position for a game position index (0-56, etc)
  Vector2 getPositionForIndex(int index) {
    // TODO: Implement full mapping
    // For now, return center to avoid errors if called
    return size / 2;
  }
}
