import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DiceComponent extends PositionComponent {
  int _currentValue = 1;

  DiceComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(60),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _drawDice();
  }

  void updateDiceValue(int value) {
    if (value >= 1 && value <= 6 && value != _currentValue) {
      _currentValue = value;
      removeAll(children);
      _drawDice();
    }
  }

  void _drawDice() {
    // Draw dice background
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white,
      children: [
        RectangleComponent(
          size: size,
          paint: Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black,
        ),
      ],
    ));

    // Draw dots based on value
    switch (_currentValue) {
      case 1:
        _addDot(size.x / 2, size.y / 2);
        break;
      case 2:
        _addDot(size.x * 0.3, size.y * 0.3);
        _addDot(size.x * 0.7, size.y * 0.7);
        break;
      case 3:
        _addDot(size.x * 0.3, size.y * 0.3);
        _addDot(size.x / 2, size.y / 2);
        _addDot(size.x * 0.7, size.y * 0.7);
        break;
      case 4:
        _addDot(size.x * 0.3, size.y * 0.3);
        _addDot(size.x * 0.7, size.y * 0.3);
        _addDot(size.x * 0.3, size.y * 0.7);
        _addDot(size.x * 0.7, size.y * 0.7);
        break;
      case 5:
        _addDot(size.x * 0.3, size.y * 0.3);
        _addDot(size.x * 0.7, size.y * 0.3);
        _addDot(size.x / 2, size.y / 2);
        _addDot(size.x * 0.3, size.y * 0.7);
        _addDot(size.x * 0.7, size.y * 0.7);
        break;
      case 6:
        _addDot(size.x * 0.3, size.y * 0.3);
        _addDot(size.x * 0.7, size.y * 0.3);
        _addDot(size.x * 0.3, size.y / 2);
        _addDot(size.x * 0.7, size.y / 2);
        _addDot(size.x * 0.3, size.y * 0.7);
        _addDot(size.x * 0.7, size.y * 0.7);
        break;
    }
  }

  void _addDot(double x, double y) {
    add(CircleComponent(
      radius: 5,
      position: Vector2(x, y),
      paint: Paint()..color = Colors.black,
      anchor: Anchor.center,
    ));
  }
}
