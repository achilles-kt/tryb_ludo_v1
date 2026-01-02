import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';
import '../../theme/app_theme.dart';
import '../common/glass_container.dart';
import '../../app.dart';

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
        final titleColor = isWin ? AppTheme.neonGreen : AppTheme.neonRed;

        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.85),
          body: Center(
            child: GlassContainer(
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              margin: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    title,
                    style: AppTheme.header.copyWith(
                      fontSize: 36,
                      color: titleColor,
                      shadows: isWin
                          ? [
                              BoxShadow(
                                color: titleColor.withOpacity(0.5),
                                blurRadius: 30,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reward Text
                  if (state.rewardText.isNotEmpty)
                    Text(
                      state.rewardText,
                      style: AppTheme.text.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: 48),

                  // Home Button
                  GestureDetector(
                    onTap: () {
                      // Use explicit navigation to ensure we land on Lobby/AppShell
                      // regardless of how we entered the game (e.g. Deep Link)
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => AppShell()),
                        (route) => false,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                          gradient: AppTheme.primaryGrad,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonBlue.withOpacity(0.4),
                              blurRadius: 15,
                              offset: Offset(0, 4),
                            )
                          ]),
                      child: Text(
                        'Back to Lobby',
                        style: AppTheme.text.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
