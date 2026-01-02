import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  final DatabaseReference _configRef = FirebaseDatabase.instance.ref('config');

  // Defaults
  static const int _defaultGameStake = 1000;
  static const int _defaultGemFee = 10;

  // Reactive values (could be Notifiers if needed, but simple getters are fine for now)
  int get gameStake => _gameStake;
  int get gemFee => _gemFee;
  bool get ageVerificationEnabled => _ageVerificationEnabled;

  // Internal storage
  int _gameStake = _defaultGameStake;
  int _gemFee = _defaultGemFee;
  bool _ageVerificationEnabled = false; // Default disabled as requested

  Future<void> init() async {
    try {
      debugPrint('CONFIG: Initializing RTDB listener...');

      // Listen for changes
      _configRef.onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          _gameStake = (val['game_stake'] as int?) ?? _defaultGameStake;
          _gemFee = (val['gem_fee'] as int?) ?? _defaultGemFee;
          _ageVerificationEnabled =
              (val['age_verification_enabled'] as bool?) ?? false;
          debugPrint(
              '✅ CONFIG UPDATED: Stake=$_gameStake, Fee=$_gemFee, AgeGate=$_ageVerificationEnabled');
        } else {
          // Fallback to defaults if config node doesn't exist
          _gameStake = _defaultGameStake;
          _gemFee = _defaultGemFee;
          _ageVerificationEnabled = false;
          debugPrint('⚠️ CONFIG: Node missing, using defaults.');
        }
      }, onError: (e) {
        debugPrint('⚠️ CONFIG LISTENER ERROR: $e');
      });

      // Perform one-time fetch to ensure we have data before we proceed (optional)
      // The listener is async, so the app might start with defaults and update split-second later.
      // That is acceptable for RTDB.
    } catch (e) {
      debugPrint('⚠️ CONFIG INIT FAILED: $e');
    }
  }
}
