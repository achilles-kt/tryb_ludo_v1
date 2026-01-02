import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/game_controller.dart';
import '../dice_widget.dart'; // For DiceTimerPainter

class DiceSpriteWidget extends StatefulWidget {
  final GameController controller;
  final double size;
  final double timeLeft;

  const DiceSpriteWidget({
    super.key,
    required this.controller,
    this.size = 60,
    this.timeLeft = 0,
  });

  @override
  State<DiceSpriteWidget> createState() => _DiceSpriteWidgetState();
}

class _DiceSpriteWidgetState extends State<DiceSpriteWidget>
    with SingleTickerProviderStateMixin {
  // CONFIG
  static const int kIdleFrames = 36;
  static const int kIdleCols = 6;

  static const int kRollFrames = 16;
  static const int kRollCols = 4;

  static const double kFrameSize = 512.0;

  // IMAGES
  ui.Image? _imgIdle;
  ui.Image? _imgRoll;
  ui.Image? _imgFaces;
  bool _assetsLoaded = false;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _loadAssets();

    // Loop animation (approx 30fps)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // 1s for 30 frames = 30fps
    )..repeat();
  }

  Future<void> _loadAssets() async {
    try {
      final idleData = await rootBundle.load('assets/dice/idle.png');
      final rollData = await rootBundle.load('assets/dice/roll.png');
      final facesData = await rootBundle.load('assets/dice/faces.png');

      final idleCodec =
          await ui.instantiateImageCodec(idleData.buffer.asUint8List());
      final rollCodec =
          await ui.instantiateImageCodec(rollData.buffer.asUint8List());
      final facesCodec =
          await ui.instantiateImageCodec(facesData.buffer.asUint8List());

      final idleFrame = await idleCodec.getNextFrame();
      final rollFrame = await rollCodec.getNextFrame();
      final facesFrame = await facesCodec.getNextFrame();

      if (mounted) {
        setState(() {
          _imgIdle = idleFrame.image;
          _imgRoll = rollFrame.image;
          _imgFaces = facesFrame.image;
          _assetsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading sprite assets: $e");
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      // Show placeholder or simple loader
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IgnorePointer(
        ignoring: true, // Allow taps to pass through to GameScreen
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Timer Ring
            Positioned.fill(
              child: CustomPaint(
                painter:
                    DiceTimerPainter(progress: widget.timeLeft.clamp(0.0, 1.0)),
              ),
            ),

            // 2. Sprite Animation (Centered)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _animController,
                  widget.controller.isRolling,
                  widget.controller.diceValue,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _SpritePainter(
                      imgIdle: _imgIdle!,
                      imgRoll: _imgRoll!,
                      imgFaces: _imgFaces!,
                      isRolling: widget.controller.isRolling.value,
                      value: widget.controller.diceValue.value,
                      animValue: _animController.value,
                      timeLeft: widget.timeLeft,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image imgIdle;
  final ui.Image imgRoll;
  final ui.Image imgFaces;
  final bool isRolling;
  final int value;
  final double animValue; // 0.0 to 1.0 (Looping)
  final double timeLeft;

  _SpritePainter({
    required this.imgIdle,
    required this.imgRoll,
    required this.imgFaces,
    required this.isRolling,
    required this.value,
    required this.animValue,
    required this.timeLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;

    // Determine which Sheet and Frame to draw
    ui.Image targetImage;
    Rect srcRect;

    if (isRolling) {
      // ----------------------------------------------------
      // STATE: ROLLING
      // Cycle through 16 frames (4x4)
      // ----------------------------------------------------
      targetImage = imgRoll;
      final totalFrames = _DiceSpriteWidgetState.kRollFrames;
      // Map 0..1 to 0..15
      int frameIndex = (animValue * totalFrames).floor() % totalFrames;

      int col = frameIndex % _DiceSpriteWidgetState.kRollCols;
      int row = frameIndex ~/ _DiceSpriteWidgetState.kRollCols;

      srcRect = Rect.fromLTWH(
          col * _DiceSpriteWidgetState.kFrameSize,
          row * _DiceSpriteWidgetState.kFrameSize,
          _DiceSpriteWidgetState.kFrameSize,
          _DiceSpriteWidgetState.kFrameSize);
    } else {
      // ----------------------------------------------------
      // STATE: IDLE or RESULT
      // ----------------------------------------------------
      if (timeLeft > 0) {
        // IDLE LOOP (Waiting for turn) (6x6)
        targetImage = imgIdle;
        final totalFrames = _DiceSpriteWidgetState.kIdleFrames;
        int frameIndex = (animValue * totalFrames).floor() % totalFrames;

        int col = frameIndex % _DiceSpriteWidgetState.kIdleCols;
        int row = frameIndex ~/ _DiceSpriteWidgetState.kIdleCols;

        srcRect = Rect.fromLTWH(
            col * _DiceSpriteWidgetState.kFrameSize,
            row * _DiceSpriteWidgetState.kFrameSize,
            _DiceSpriteWidgetState.kFrameSize,
            _DiceSpriteWidgetState.kFrameSize);
      } else {
        // RESULT / STATIC (Showing Face)
        // Strip is 6x1
        targetImage = imgFaces;

        // Ensure value 1-6 maps to 0-5
        int frameIndex = (value - 1).clamp(0, 5);

        srcRect = Rect.fromLTWH(
            frameIndex * 512.0, // Face strip still assumes 512
            0.0,
            512.0,
            512.0);
      }
    }

    // Destination is the full widget size
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(targetImage, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.isRolling != isRolling ||
        oldDelegate.value != value ||
        oldDelegate.timeLeft != timeLeft;
  }
}
