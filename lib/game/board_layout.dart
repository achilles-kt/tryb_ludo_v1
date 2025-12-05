import 'package:flame/components.dart';

enum PlayerColor { red, green, yellow, blue }

class BoardLayout {
  BoardLayout._();

  // Board is 340x340 inside BoardComponent
  static const double boardSize = 340;
  static const int gridSize = 15;

  static double get cellSize => boardSize / gridSize;

  /// Returns center world position (within BoardComponent) for a given grid cell.
  static Vector2 cellCenter(int row, int col) {
    final cs = cellSize;
    final x = (col + 0.5) * cs;
    final y = (row + 0.5) * cs;
    return Vector2(x, y);
  }

  /// Global track of 52 cells in board-relative grid coordinates.
  static final List<Vector2> globalTrack = _buildGlobalTrack();

  /// Home path (towards center) for each player: 6 steps each.
  static final Map<PlayerColor, List<Vector2>> homePath = _buildHomePaths();

  /// Starting home positions (the yard) – where 4 tokens are placed initially.
  static final Map<PlayerColor, List<Vector2>> homeYard = _buildHomeYards();

  /// Map a logical position index to a board position:
  /// -1 = yard slot
  /// 0–51 = main loop
  /// 52–57 = home column
  static Vector2 positionFor(
    PlayerColor color,
    int logicalPos, {
    int tokenIndexForYard = 0,
  }) {
    if (logicalPos < 0) {
      final yard = homeYard[color]!;
      return yard[tokenIndexForYard % yard.length];
    }

    // Main loop
    if (logicalPos >= 0 && logicalPos <= 51) {
      final startOffset = _startOffset(color);
      final idx = (startOffset + logicalPos) % 52;
      return globalTrack[idx];
    }

    // Home path (52–57)
    final homeIdx = logicalPos - 52;
    final path = homePath[color]!;
    final clamped = homeIdx.clamp(0, path.length - 1);
    return path[clamped];
  }

  // ------------ INTERNAL BUILDERS ------------ //

  static List<Vector2> _buildGlobalTrack() {
    final List<Vector2> pts = [];
    Vector2 cc(int row, int col) => cellCenter(row, col);

    // Standard Ludo Path (52 steps)
    // Starting from Red's start position (13, 6) and going clockwise

    // 1. Red's vertical up (5 steps)
    pts.add(cc(13, 6));
    pts.add(cc(12, 6));
    pts.add(cc(11, 6));
    pts.add(cc(10, 6));
    pts.add(cc(9, 6));

    // 2. Red's horizontal left (6 steps)
    pts.add(cc(8, 5));
    pts.add(cc(8, 4));
    pts.add(cc(8, 3));
    pts.add(cc(8, 2));
    pts.add(cc(8, 1));
    pts.add(cc(8, 0));

    // 3. Turn Up (1 step)
    pts.add(cc(7, 0));

    // 4. Green's horizontal right (6 steps)
    pts.add(cc(6, 0));
    pts.add(cc(6, 1));
    pts.add(cc(6, 2));
    pts.add(cc(6, 3));
    pts.add(cc(6, 4));
    pts.add(cc(6, 5));

    // 5. Green's vertical up (6 steps)
    pts.add(cc(5, 6));
    pts.add(cc(4, 6));
    pts.add(cc(3, 6));
    pts.add(cc(2, 6));
    pts.add(cc(1, 6));
    pts.add(cc(0, 6));

    // 6. Turn Right (1 step)
    pts.add(cc(0, 7));

    // 7. Yellow's vertical down (6 steps)
    pts.add(cc(0, 8));
    pts.add(cc(1, 8));
    pts.add(cc(2, 8));
    pts.add(cc(3, 8));
    pts.add(cc(4, 8));
    pts.add(cc(5, 8));

    // 8. Yellow's horizontal right (6 steps)
    pts.add(cc(6, 9));
    pts.add(cc(6, 10));
    pts.add(cc(6, 11));
    pts.add(cc(6, 12));
    pts.add(cc(6, 13));
    pts.add(cc(6, 14));

    // 9. Turn Down (1 step)
    pts.add(cc(7, 14));

    // 10. Blue's horizontal left (6 steps)
    pts.add(cc(8, 14));
    pts.add(cc(8, 13));
    pts.add(cc(8, 12));
    pts.add(cc(8, 11));
    pts.add(cc(8, 10));
    pts.add(cc(8, 9));

    // 11. Blue's vertical down (6 steps)
    pts.add(cc(9, 8));
    pts.add(cc(10, 8));
    pts.add(cc(11, 8));
    pts.add(cc(12, 8));
    pts.add(cc(13, 8));
    pts.add(cc(14, 8));

    // 12. Turn Left (1 step)
    pts.add(cc(14, 7));

    // 13. Red's vertical up (1 step to connect back to start)
    pts.add(cc(14, 6));

    return pts;
  }

  static Map<PlayerColor, List<Vector2>> _buildHomePaths() {
    Vector2 cc(int row, int col) => cellCenter(row, col);
    return {
      PlayerColor.red: [
        cc(13, 7),
        cc(12, 7),
        cc(11, 7),
        cc(10, 7),
        cc(9, 7),
        cc(8, 7), // Finish
      ],
      PlayerColor.green: [
        cc(7, 1),
        cc(7, 2),
        cc(7, 3),
        cc(7, 4),
        cc(7, 5),
        cc(7, 6), // Finish
      ],
      PlayerColor.yellow: [
        cc(1, 7),
        cc(2, 7),
        cc(3, 7),
        cc(4, 7),
        cc(5, 7),
        cc(6, 7), // Finish
      ],
      PlayerColor.blue: [
        cc(7, 13),
        cc(7, 12),
        cc(7, 11),
        cc(7, 10),
        cc(7, 9),
        cc(7, 8), // Finish
      ],
    };
  }

  static Map<PlayerColor, List<Vector2>> _buildHomeYards() {
    Vector2 cc(int row, int col) => cellCenter(row, col);
    return {
      PlayerColor.red: [
        cc(11, 2),
        cc(11, 3),
        cc(12, 2),
        cc(12, 3),
      ],
      PlayerColor.green: [
        cc(2, 2),
        cc(2, 3),
        cc(3, 2),
        cc(3, 3),
      ],
      PlayerColor.yellow: [
        cc(2, 11),
        cc(2, 12),
        cc(3, 11),
        cc(3, 12),
      ],
      PlayerColor.blue: [
        cc(11, 11),
        cc(11, 12),
        cc(12, 11),
        cc(12, 12),
      ],
    };
  }

  static int _startOffset(PlayerColor color) {
    // Where each color's index 0 starts on the globalTrack
    switch (color) {
      case PlayerColor.red:
        return 0;
      case PlayerColor.green:
        return 13;
      case PlayerColor.yellow:
        return 26;
      case PlayerColor.blue:
        return 39;
    }
  }
}
