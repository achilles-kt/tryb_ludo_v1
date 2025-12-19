import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Public Dice widget used by DiceOverlay.
class DiceWidget extends StatelessWidget {
  final int value;
  final double timeLeft; // 0.0 to 1.0
  final VoidCallback? onTap;
  final double size;
  final bool isBlank;

  const DiceWidget({
    super.key,
    required this.value,
    required this.timeLeft,
    this.onTap,
    this.size = 80.0,
    this.isBlank = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: DiceTimerPainter(progress: timeLeft.clamp(0.0, 1.0)),
              ),
            ),

            // Realistic 3D dice image
            SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: value >= 1 && value <= 6 && !isBlank
                  ? Image.asset(
                      'assets/dice/dice_$value.png',
                      fit: BoxFit.contain,
                    )
                  : const SizedBox.shrink(), // Blank dice
            ),
          ],
        ),
      ),
    );
  }
}

/// Timer arc painter
class DiceTimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  const DiceTimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;

    final arcPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw arc from top, going clockwise
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius - 2),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(DiceTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
