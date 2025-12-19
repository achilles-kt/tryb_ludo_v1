import 'package:flutter_test/flutter_test.dart';
import '../lib/game/logic/ludo_rules.dart';

void main() {
  group('LudoRules', () {
    test('Yard Logic: Needs 6 to exit', () {
      expect(LudoRules.canMove(-1, 1), isFalse);
      expect(LudoRules.canMove(-1, 5), isFalse);
      expect(LudoRules.canMove(-1, 6), isTrue);
    });

    test('Track Logic: Valid moves', () {
      expect(LudoRules.canMove(0, 1), isTrue);
      expect(LudoRules.canMove(50, 6), isTrue);
    });

    test('Home Path Logic: No overshooting 57', () {
      expect(LudoRules.canMove(56, 1), isTrue); // Lands on 57 (Goal)
      expect(LudoRules.canMove(56, 2), isFalse); // Overshoots
      expect(LudoRules.canMove(57, 1), isFalse); // Already at goal
    });

    test('Calculation Logic', () {
      expect(LudoRules.calculateNewPosition(-1, 6), equals(0));
      expect(LudoRules.calculateNewPosition(10, 5), equals(15));
      expect(LudoRules.calculateNewPosition(56, 2), isNull);
    });
  });
}
