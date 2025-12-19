class LudoRules {
  /// Validates if a token can move given the dice value.
  ///
  /// [currentPosition]: -1 for Yard, 0-51 for Track, 52-57 for Home Path.
  /// [diceValue]: 1-6.
  static bool canMove(int currentPosition, int diceValue) {
    // 1. Yard Logic: Needs a 6 to start
    if (currentPosition == -1) {
      return diceValue == 6;
    }

    // 2. Track & Home Logic
    // Token cannot exceed position 57 (Target Home)
    if (currentPosition + diceValue <= 57) {
      return true;
    }

    return false;
  }

  /// Calculates the new position for a token.
  /// Returns null if the move is invalid.
  static int? calculateNewPosition(int currentPosition, int diceValue) {
    if (!canMove(currentPosition, diceValue)) {
      return null;
    }

    if (currentPosition == -1) {
      return 0; // Move to start
    }

    return currentPosition + diceValue;
  }
}
