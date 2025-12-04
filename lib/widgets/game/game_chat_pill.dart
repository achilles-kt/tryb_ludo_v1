import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';

class GameChatPill extends StatelessWidget {
  final LudoGame game;
  const GameChatPill({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: Container(
          height: 48,
          width: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2D3E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Open chat sheet
              },
              borderRadius: BorderRadius.circular(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Chat with players',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
