import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';

class EndGameOverlay extends StatelessWidget {
  final LudoGame game;
  const EndGameOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameEndState?>(
      valueListenable: game.gameEndNotifier,
      builder: (ctx, state, _) {
        if (state == null) return const SizedBox.shrink();

        final title = state.isWin ? 'VICTORY!' : 'DEFEAT';
        final color = state.isWin ? Colors.greenAccent : Colors.redAccent;

        return Container(
          color: const Color.fromARGB(240, 10, 10, 10),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.rewardText,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // back to lobby
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Back to Lobby'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
