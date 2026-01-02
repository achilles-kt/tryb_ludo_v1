import 'package:flutter/material.dart';
import '../chat/chat_sheet.dart';

class GameBottomControls extends StatelessWidget {
  final String? gameId;
  final bool isTeamChat;
  final bool showTeamToggle;
  final VoidCallback? onToggleTeam;
  final Map<String, dynamic>? players;

  const GameBottomControls({
    super.key,
    this.gameId,
    this.isTeamChat = false,
    this.showTeamToggle = true,
    this.onToggleTeam,
    this.players,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC0F1218), Colors.transparent],
        ),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: const Color(0xFF14161b),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => ChatSheet(
                gameId: gameId,
                initialIsTeamChat: isTeamChat,
                showTeamToggle: showTeamToggle,
                players: players,
              ),
            );
          },
          child: Container(
            width: w * 0.90,
            height: 52,
            decoration: BoxDecoration(
              color: isTeamChat
                  ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isTeamChat
                    ? const Color(0xFFC0C0C0)
                    : Colors.white.withValues(alpha: 0.16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                if (showTeamToggle) ...[
                  GestureDetector(
                    onTap: () {
                      onToggleTeam?.call(); // Toggle specific button
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTeamChat
                            ? const Color(0xFFC0C0C0)
                            : Colors.deepPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isTeamChat ? "TEAM" : "ALL",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isTeamChat ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    isTeamChat ? 'Message Team...' : 'Tap to game chat...',
                    style: TextStyle(
                        color: isTeamChat
                            ? const Color(0xFFC0C0C0)
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.emoji_emotions_outlined,
                    color: Colors.white70, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
