import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../widgets/modals/profile_edit_modal.dart';
// import '../services/auth_service.dart'; // Unused

enum NudgeType { none, soft, hard }

class ConversionService {
  ConversionService._();
  static final ConversionService instance = ConversionService._();

  // In-Memory Session State
  bool _shownThisSession = false;

  /// Call this when the app starts (after Auth is ready)
  Future<void> checkSessionStart(BuildContext context) async {
    if (_shownThisSession) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if already fully converted
    // (We consider "converted" if they have a linked credential that isn't anonymous,
    // but wait, isAnon is true for guests. If they linked Google, isAnon becomes false?
    // Actually, Firebase User.isAnonymous is false if linked. Yes.)
    if (!user.isAnonymous) return;

    // Fetch User Stats & Flags
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('users/${user.uid}').get();

    if (!snapshot.exists) return;
    final data = snapshot.value as Map?;
    if (data == null) return;

    // Check Trigger: Day 2 App Open
    final createdAt = data['createdAt'] as int? ?? 0;

    // Ignore if createdAt is invalid (0) or future (sanity check)
    if (createdAt <= 0) return;

    // Check if Profile is already edited (Name/City/Country)
    final profile = data['profile'] as Map?;
    if (profile != null) {
      final name = profile['displayName'] as String?;
      final city = profile['city'] as String?;
      final country = profile['country'] as String?;
      if ((name != null && name.isNotEmpty) ||
          (city != null && city.isNotEmpty) ||
          (country != null && country.isNotEmpty)) {
        // User engaged with profile, skip hard nudge
        return;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffHours = (now - createdAt) / (1000 * 60 * 60);

    if (diffHours >= 24) {
      // It's been more than 24 hours. Potential Hard Nudge.
      // Check last Nudge Time (Weekly logic)
      final flags = data['flags'] as Map?;
      final lastNudge = flags?['lastNudgeTime'] as int? ?? 0;
      final diffDaysSinceNudge = (now - lastNudge) / (1000 * 60 * 60 * 24);

      if (lastNudge == 0 || diffDaysSinceNudge >= 7) {
        // Trigger Hard Nudge
        if (context.mounted) {
          _showNudge(context, NudgeType.hard);
        }
      }
    }
  }

  /// Call this after a game finishes
  Future<void> checkGameCompletion(BuildContext context) async {
    if (_shownThisSession) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return;

    final db = FirebaseDatabase.instance.ref();
    final statsSnap =
        await db.child('users/${user.uid}/stats/gamesPlayed').get();
    final gamesPlayed = (statsSnap.value as int?) ?? 0;

    // Soft Nudge: After 1st game
    if (gamesPlayed == 1) {
      if (context.mounted) _showNudge(context, NudgeType.soft);
      return;
    }

    // Hard Nudge: After 3rd game
    if (gamesPlayed == 3) {
      if (context.mounted) _showNudge(context, NudgeType.hard);
      return;
    }
  }

  /// Manually Triggered Nudge (e.g. from Profile Tap if eligible?)
  /// Or just standard profile edit.
  /// But if we want to "Upgrade" the profile view to a nudge:
  void showProfile(BuildContext context, {bool isHardNudge = false}) {
    // Always allow manual opening, but maybe with nudge styling if not converted?
    // The "Nudge" generally implies specific copy.
    // If user taps profile, they naturally want to edit.
    // We can just show the standard modal, maybe with "Save Progress" header if Anon.

    // Note: If manual, we don't block "shownThisSession".
    // But we might want to capture the style.

    final user = FirebaseAuth.instance.currentUser;
    final isAnon = user?.isAnonymous ?? false;

    // If Anon, treating it as "Edit" mode but maybe with "Save Progress" flair?
    // For now, let's keep manual tap as 'edit' mode to not annoy.
    // OR if the user asked "User opens Profile tab" -> Hard Nudge (Value Unlock).

    if (isAnon && isHardNudge) {
      _showNudge(context, NudgeType.hard);
    } else {
      // Standard Edit
      _showModal(context, NudgeType.none);
    }
  }

  void _showNudge(BuildContext context, NudgeType type) {
    _shownThisSession = true;
    _markNudgeShown(); // Persist timestamp
    _showModal(context, type);
  }

  void _showModal(BuildContext context, NudgeType type) {
    showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfileEditModal(
            nudgeType: type, // passing type
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        });
  }

  Future<void> _markNudgeShown() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseDatabase.instance
        .ref('users/${user.uid}/flags/lastNudgeTime')
        .set(ServerValue.timestamp);
  }
}
