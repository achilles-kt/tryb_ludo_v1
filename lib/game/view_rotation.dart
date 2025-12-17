import 'board_layout.dart';

/// Helper class to handle view rotation logic.
/// Each client sees the board rotated so that the local player is always at bottom-left.
/// Player colors remain consistent across all clients.
class ViewRotation {
  final int localPlayerSeat;
  final Map<String, dynamic> players;

  ViewRotation({
    required this.localPlayerSeat,
    required this.players,
  });

  /// Maps an actual seat number to a visual seat number on the current client.
  /// The local player (at localPlayerSeat) always appears at visual seat 0 (bottom-left).
  ///
  /// Visual seats:
  /// - 0 = Bottom-Left (local player)
  /// - 1 = Top-Left
  /// - 2 = Top-Right
  /// - 3 = Bottom-Right
  int getVisualSeat(int actualSeat) {
    // Calculate rotation offset so local player appears at position 0 (BL)
    return (actualSeat - localPlayerSeat + 4) % 4;
  }

  /// Reverse mapping: given a visual seat, returns the actual seat number.
  int getActualSeat(int visualSeat) {
    return (visualSeat + localPlayerSeat) % 4;
  }

  /// Gets the consistent color for a player from server data.
  /// Falls back to seat-based color if not available (for backward compatibility).
  PlayerColor getColorForPlayer(String uid) {
    final playerData = players[uid];
    if (playerData == null) return PlayerColor.red;

    // Try to get color from server (new system)
    final colorStr = playerData['color'] as String?;
    if (colorStr != null) {
      return _parseColor(colorStr);
    }

    // Fallback to seat-based color (old system for backward compatibility)
    final seat = playerData['seat'] as int? ?? 0;
    return _colorForSeat(seat);
  }

  /// Returns the UID of the player at a given visual seat.
  /// Returns null if no player is at that position.
  String? getPlayerAtVisualSeat(int visualSeat) {
    final actualSeat = getActualSeat(visualSeat);

    // Find player with matching seat
    for (final entry in players.entries) {
      final playerData = entry.value;
      if (playerData is Map && playerData['seat'] == actualSeat) {
        return entry.key;
      }
    }

    return null;
  }

  /// Converts color string to PlayerColor enum.
  PlayerColor _parseColor(String colorStr) {
    return switch (colorStr.toLowerCase()) {
      'red' => PlayerColor.red,
      'green' => PlayerColor.green,
      'yellow' => PlayerColor.yellow,
      'blue' => PlayerColor.blue,
      _ => PlayerColor.red,
    };
  }

  /// Gets the color to use for rendering tokens on the board.
  /// This is based on the VISUAL seat (rotated), not the actual seat.
  /// This ensures tokens appear at the correct position relative to the local player.
  PlayerColor getBoardColorForPlayer(String uid) {
    final playerData = players[uid];
    if (playerData == null) return PlayerColor.red;

    // Get the player's actual seat
    final actualSeat = playerData['seat'] as int? ?? 0;

    // Convert to visual seat (rotated)
    final visualSeat = getVisualSeat(actualSeat);

    // Return color based on visual seat
    return _colorForSeat(visualSeat);
  }

  /// Fallback: converts seat to color (old system).
  PlayerColor _colorForSeat(int seat) {
    return switch (seat) {
      0 => PlayerColor.red,
      1 => PlayerColor.green,
      2 => PlayerColor.yellow,
      3 => PlayerColor.blue,
      _ => PlayerColor.red,
    };
  }
}
