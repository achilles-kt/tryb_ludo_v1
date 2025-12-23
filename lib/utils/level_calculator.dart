class LevelInfo {
  final int level;
  final int currentThreshold;
  final int nextThreshold;
  final int totalGold;

  LevelInfo({
    required this.level,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.totalGold,
  });

  double get progress {
    if (nextThreshold == currentThreshold) return 1.0;
    return (totalGold - currentThreshold) / (nextThreshold - currentThreshold);
  }
}

class LevelCalculator {
  static LevelInfo calculate(int totalGold) {
    // 1. Initial 5 Levels: +500 gap
    // L1: 500
    // L2: 1500 (500 + 1000? No, usually levels accumulate. User said "Cumulative gold earnings")
    // Let's re-read requirements carefully.
    // L1 - Cumulative 500
    // L2 - Cumulative 1500
    // L3 - Cumulative 3000
    // L4 - 5000
    // L5 - 7500
    // L6 - 10000
    // L7 - 12500 (Gap becomes 2500 fixed)

    // Gaps:
    // 0 -> 500 (L1) (Base Level 0? User says "Level 1 - Cumulative 500". So if < 500, Level 0?)
    // Actually, usually you start at Level 1.
    // Let's assume:
    // 0-499: Level 1
    // 500-1499: Level 2
    // 1500-2999: Level 3
    // 3000-4999: Level 4
    // 5000-7499: Level 5
    // 7500-9999: Level 6
    // 10000-12499: Level 7
    // ... +2500

    // Check user List:
    // Level 1 - 500 (Implies reaching 500 GETS you Level 1? Or you ARE level 1 until 500?)
    // Usually "Level 2 @ 1500" means you are L1 until 1500.
    // But check the gap progression:
    // 500 -> 1500 (+1000)
    // 1500 -> 3000 (+1500)
    // 3000 -> 5000 (+2000)
    // 5000 -> 7500 (+2500)
    // 7500 -> 10000 (+2500)
    // 10000 -> 12500 (+2500) ... constant 2500.

    // So the thresholds to REACH the NEXT level are:
    // Start L1.
    // To L2: 500 (Gap 500)
    // To L3: 1500 (Gap 1000)
    // To L4: 3000 (Gap 1500)
    // To L5: 5000 (Gap 2000)
    // To L6: 7500 (Gap 2500)
    // To L7: 10000 (Gap 2500)

    // So if totalGold < 500: Level 1. Next: 500.
    // If totalGold < 1500: Level 2. Next: 1500. (Wait, user said "Level 1 - 500". Maybe that means you attain Level 1 AT 500?)
    // "Level 1 - Cumulative gold 500 earnings". This phrasing is tricky.
    // Usually you start at Level 1. Or Level 0.
    // Given the context of games, likely:
    // < 500: Level 1 (Beginner)
    // >= 500: Level 2
    // ...
    // Let's stick to the threshold logic:
    // The "Goal" for Level 1 is 500.
    // The "Goal" for Level 2 is 1500.

    // Manual Thresholds
    final thresholds = [500, 1500, 3000, 5000, 7500, 10000];

    // Check initial irregulars
    for (int i = 0; i < thresholds.length; i++) {
      if (totalGold < thresholds[i]) {
        // We are in this bracket
        return LevelInfo(
            level: i + 1,
            currentThreshold: i == 0 ? 0 : thresholds[i - 1],
            nextThreshold: thresholds[i],
            totalGold: totalGold);
      }
    }

    // If we passed the explicit list (>= 10000)
    // Level 7 starts at 10000.
    // Gaps are fixed 2500.
    // L7: 10000 -> 12500
    // L8: 12500 -> 15000

    int basePostFixed = 10000;
    int accumulated = totalGold - basePostFixed;
    int levelsGained = accumulated ~/ 2500;

    int currentLevel = 7 + levelsGained;
    int currentLevelStart = basePostFixed + (levelsGained * 2500);
    int nextLevelStart = currentLevelStart + 2500;

    return LevelInfo(
        level: currentLevel,
        currentThreshold: currentLevelStart,
        nextThreshold: nextLevelStart,
        totalGold: totalGold);
  }
}
