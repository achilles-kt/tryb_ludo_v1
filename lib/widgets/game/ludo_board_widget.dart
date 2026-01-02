import 'package:flutter/material.dart';
import 'package:flame/game.dart' hide Matrix4;
import '../../game/ludo_game.dart';

class LudoBoardWidget extends StatelessWidget {
  final LudoGame game;
  final double boardSize;
  final double top;
  final double left;

  const LudoBoardWidget({
    super.key,
    required this.game,
    required this.boardSize,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: boardSize,
      height: boardSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GameWidget(game: game),
      ),
    );
  }
}
