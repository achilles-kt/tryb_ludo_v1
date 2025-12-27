import 'package:flutter/material.dart';
import '../models/activity_item.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class ActivityItemRenderer extends StatelessWidget {
  final ActivityItem item;
  final bool isMe;

  const ActivityItemRenderer({
    Key? key,
    required this.item,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Switch on Type
    switch (item.type) {
      case ActivityType.gameResult:
        return _buildGameResultCard(context);
      case ActivityType.gameInvite:
        return _buildGameInvite(context);
      case ActivityType.text:
      default:
        return _buildTextBubble(context);
    }
  }

  Widget _buildTextBubble(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.neonBlue.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          border: Border.all(
            color: isMe ? AppTheme.neonBlue.withOpacity(0.5) : Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isTeam)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 12, color: AppTheme.gold),
                    const SizedBox(width: 4),
                    Text("TEAM",
                        style: AppTheme.label
                            .copyWith(fontSize: 10, color: AppTheme.gold)),
                  ],
                ),
              ),
            Text(
              item.text,
              style: AppTheme.text.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameResultCard(BuildContext context) {
    final winner = item.payload['winner'] ?? 'Unknown';
    final score = item.payload['score'] ?? '0-0';
    final mode = item.payload['mode'] ?? 'Standard';

    return Align(
      alignment: Alignment.center, // Results are usually centered
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 280,
        child: GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.4),
            borderColor: AppTheme.gold,
            borderOpacity: 0.5,
            child: Column(
              children: [
                const Icon(Icons.emoji_events, color: AppTheme.gold, size: 32),
                const SizedBox(height: 8),
                Text(
                  winner == 'You' ? "VICTORY" : "GAME OVER",
                  style: AppTheme.header.copyWith(
                      fontSize: 18,
                      color: winner == 'You' ? AppTheme.gold : Colors.white70),
                ),
                const SizedBox(height: 4),
                Text("$mode • $score", style: AppTheme.label),
                const SizedBox(height: 12),
                // Avatars row?
                // Minimal for now
                ElevatedButton(
                  onPressed: () {
                    // Logic to view details?
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonBlue,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: const Text("View Stats"),
                )
              ],
            )),
      ),
    );
  }

  Widget _buildGameInvite(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 260,
        child: GlassContainer(
          borderRadius: 12,
          padding: const EdgeInsets.all(12),
          color: AppTheme.neonBlue.withOpacity(0.1),
          borderColor: AppTheme.neonBlue,
          borderOpacity: 1.0,
          child: Column(
            children: [
              const Text("🎮 Game Invite",
                  style: TextStyle(
                      color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(item.text,
                  textAlign: TextAlign.center, style: AppTheme.text),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Join Logic
                },
                child: const Text("Join Game"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
