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
      final totalGold = (snap.value as num?)?.toInt() ?? 0;
      return LevelCalculator.calculate(totalGold);
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
  }) async {
    if (currentUid == null) throw Exception("User not logged in");

    await _db.ref('users/$currentUid/profile').update({
      'displayName': name,
      'avatarUrl': avatar,
      'city': city,
      'country': country,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> linkPhoneNumber({required String number}) async {
    if (currentUid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .ref('users/$currentUid/phone')
        .set({'number': number, 'verified': true, 'verifiedAt': now});
    await _db.ref('users/$currentUid/flags/phoneVerified').set(true);
  }
}
