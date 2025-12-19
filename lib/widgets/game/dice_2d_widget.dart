import 'package:flutter/material.dart';
import '../dice_widget.dart';

class Dice2DWidget extends StatefulWidget {
  final bool isRolling;
  final int value;
  final double timeLeft;
  final double size;
  final bool isBlank;

  const Dice2DWidget({
    super.key,
    required this.isRolling,
    required this.value,
    this.timeLeft = 0,
    required this.size,
    this.isBlank = false,
  });

  @override
  State<Dice2DWidget> createState() => _Dice2DWidgetState();
}

class _Dice2DWidgetState extends State<Dice2DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.isRolling) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(Dice2DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _controller.repeat();
    } else if (!widget.isRolling && oldWidget.isRolling) {
      _controller.stop();
      _controller.value = 0;
    }
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
        final angle = _controller.value * 2 * 3.14159;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle)
            ..rotateY(angle * 1.5),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: DiceWidget(
        size: widget.size,
        value: widget.value,
        timeLeft: widget.timeLeft,
        isBlank: widget.isBlank,
      ),
    );
  }
}
