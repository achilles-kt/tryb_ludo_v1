import 'dart:math';
import 'package:flutter/material.dart';

class FlyingBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final Offset startPos;
  final Offset targetPos;
  final VoidCallback onComplete;

  const FlyingBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.startPos,
    required this.targetPos,
    required this.onComplete,
  });

  @override
  State<FlyingBubble> createState() => _FlyingBubbleState();
}

class _FlyingBubbleState extends State<FlyingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;
  late Animation<Offset> _positionAnim;

  // Animation Timeline (Total 4500ms)
  // 0.00 - 0.10 (450ms):  Detach & Scale Up (Start)
  // 0.10 - 0.30 (900ms):  Move to "Bounce Point" (Midway)
  // 0.30 - 0.50 (900ms):  Move to Center
  // 0.50 - 0.80 (1350ms): Center Antics (Double Bounce)
  // 0.80 - 0.95 (675ms):  Fly Back to Start
  // 0.95 - 1.00 (225ms):  Disappear

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    // Calculate an intermediate "Bounce Point" on the board
    // Roughly 1/3 to 1/2 way to center, maybe slightly offset?
    final dx = (widget.targetPos.dx - widget.startPos.dx);
    final dy = (widget.targetPos.dy - widget.startPos.dy);
    final bouncePoint = widget.startPos + Offset(dx * 0.4, dy * 0.4);

    // --- SCALE ANIMATION ---
    _scaleAnim = TweenSequence<double>([
      // 0.0 - 0.1: Pop Up (0 -> 2.0)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 2.0), weight: 10),
      // 0.1 - 0.5: Move to Center (Stay Big ~2.0)
      TweenSequenceItem(tween: ConstantTween(2.0), weight: 40),
      // 0.5 - 0.8: Center Double Bounce (Pulse 2.0 -> 2.5 -> 1.8 -> 2.5 -> 2.0)
      TweenSequenceItem(
        tween: TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 2.0, end: 2.5), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 2.5, end: 1.8), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 1.8, end: 2.5), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 2.5, end: 2.0), weight: 25),
        ]),
        weight: 30,
      ),
      // 0.8 - 0.95: Fly Back (Shrink slightly 2.0 -> 1.0)
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 1.0), weight: 15),
      // 0.95 - 1.0: Disappear (1.0 -> 0.0)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 5),
    ]).animate(_controller);

    // --- POSITION ANIMATION ---
    _positionAnim = TweenSequence<Offset>([
      // 0.0 - 0.1: Stay at Start (while popping up)
      TweenSequenceItem(tween: ConstantTween(widget.startPos), weight: 10),
      // 0.1 - 0.3: Move to Bounce Point (Curve)
      TweenSequenceItem(
          tween: Tween(begin: widget.startPos, end: bouncePoint)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      // 0.3 - 0.5: Move to Center (Bounce/Arc effect)
      TweenSequenceItem(
          tween: Tween(begin: bouncePoint, end: widget.targetPos).chain(
              CurveTween(curve: Curves.bounceOut)), // Bounce effect on arrival?
          weight: 20),
      // 0.5 - 0.8: Stay at Center (while pulsing)
      TweenSequenceItem(tween: ConstantTween(widget.targetPos), weight: 30),
      // 0.8 - 1.0: Fly Back to Start
      TweenSequenceItem(
          tween: Tween(begin: widget.targetPos, end: widget.startPos)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 20),
    ]).animate(_controller);

    // --- ROTATION (Wiggle) ---
    _rotateAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: ConstantTween(0.0), weight: 50), // No rot until center
      TweenSequenceItem(
          tween: TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 25),
            TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 50),
            TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 25),
          ]),
          weight: 30), // Wiggle at center
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnim.value.dx,
          top: _positionAnim.value.dy,
          child: Transform.translate(
            offset: const Offset(-20, -20), // Center pivot roughly?
            child: Transform.rotate(
              angle: _rotateAnim.value * 2 * pi,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: _emojiContent(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emojiContent() {
    // Just the text, assuming emoji.
    // Remove bubble decoration to look "detached" as requested.
    return Text(
      widget.text,
      style: const TextStyle(
          fontSize: 24, // Base size, will be scaled up 2x -> 48
          // No shadows for clean emoji look? Or Keep simple shadow?
          shadows: [
            Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26),
          ]),
    );
  }
}
