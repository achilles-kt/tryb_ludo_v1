import 'package:flutter/material.dart';
import '../../utils/level_calculator.dart';

class LevelProgressCard extends StatelessWidget {
  final LevelInfo? levelInfo;

  const LevelProgressCard({super.key, required this.levelInfo});

  @override
  Widget build(BuildContext context) {
    if (levelInfo == null) return const SizedBox.shrink();

    const cardBg = Color(0xFF181B21);
    const gold = Color(0xFFFACC15);
    const textMuted = Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("LEVEL PROGRESS",
              style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelInfo!.progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF0B0D11),
              color: gold,
            ),
          ),
          const SizedBox(height: 8),
          Text("${levelInfo!.totalGold} / ${levelInfo!.nextThreshold} XP",
              style: const TextStyle(color: textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
