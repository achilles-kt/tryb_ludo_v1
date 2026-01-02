import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../utils/level_calculator.dart';

class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  static UserProfileService get instance => _instance;
  UserProfileService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<LevelInfo?> fetchLevelInfo() async {
    if (currentUid == null) return null;
    try {
      final snap = await _db.ref('users/$currentUid/wallet/totalEarned').get();
      final val = snap.value;

      num totalGold = 0;
      if (val is num) {
        totalGold = val;
      } else if (val != null) {
        debugPrint(
            "WARNING: totalEarned is not a number: $val (Type: ${val.runtimeType})");
        // Attempt parse?
        if (val is String) totalGold = num.tryParse(val) ?? 0;
      }

      return LevelCalculator.calculate(totalGold.toInt());
    } catch (e) {
      debugPrint("UserProfileService: Error fetching level: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchLinkedPhone() async {
    if (currentUid == null) return null;
    try {
      final snap = await _db.ref('users/$currentUid/phone').get();
      if (snap.exists && snap.value is Map) {
        return Map<String, dynamic>.from(snap.value as Map);
      }
    } catch (e) {
      debugPrint("UserProfileService: Error fetching phone: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (currentUid == null) return null;
    try {
      final snap = await _db.ref('users/$currentUid/profile').get();
      if (snap.exists && snap.value is Map) {
        return Map<String, dynamic>.from(snap.value as Map);
      }
    } catch (e) {
      debugPrint("UserProfileService: Error fetching profile: $e");
    }
    return null;
  }

  Future<void> updateProfile({
    required String name,
    required String avatar,
    required String city,
    required String country,
    String? gender, // New optional parameter
  }) async {
    if (currentUid == null) throw Exception("User not logged in");

    final updates = {
      'displayName': name,
      'avatarUrl': avatar,
      'city': city,
      'country': country,
      'updatedAt': ServerValue.timestamp,
    };

    if (gender != null) {
      updates['gender'] = gender;
    }

    await _db.ref('users/$currentUid/profile').update(updates);
  }

  Future<void> linkPhoneNumber({required String number}) async {
    if (currentUid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Update Profile Logic
    await _db
        .ref('users/$currentUid/phone')
        .set({'number': number, 'verified': true, 'verifiedAt': now});
    await _db.ref('users/$currentUid/flags/phoneVerified').set(true);

    // 2. Register for Discovery (Cloud Function)
    try {
      await FirebaseFunctions.instance.httpsCallable('registerPhone').call({
        'phone': number,
      });
      await _db.ref('users/$currentUid/flags/contactsSynced').set(
          false); // Reset sync flag to encourage re-sync? Or just let them be discovery-ready.
    } catch (e) {
      debugPrint("UserProfileService: Failed to register phone index: $e");
      // Fallback? If this fails, they won't be discoverable.
      // We should probably rethrow or show error, but for now log it.
    }
  }
}
