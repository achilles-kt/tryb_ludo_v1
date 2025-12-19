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

        final isWin = state.isWin;
        final title = isWin ? 'VICTORY' : 'DEFEAT';
        final titleColor = isWin
            ? const Color(0xFF22C55E) // Neon Green
            : const Color(0xFFFF0033); // Neon Red

        return Scaffold(
          backgroundColor: const Color.fromRGBO(10, 10, 10, 0.95),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins', // Assuming available or fallback
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    shadows: isWin
                        ? [
                            BoxShadow(
                              color: const Color.fromRGBO(34, 197, 94, 0.5),
                              blurRadius: 20,
                            ),
                          ]
                        : [],
                  ),
                ),
                const SizedBox(height: 12),

                // Reward Text (Keeping existing logic but styling it)
                if (state.rewardText.isNotEmpty)
                  Text(
                    state.rewardText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const SizedBox(height: 48),

                // Home Button
                GestureDetector(
                  onTap: () {
                    // Pop Dialog
                    Navigator.of(context).pop();
                    // Pop GameScreen to return to Lobby
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Back to Lobby',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
