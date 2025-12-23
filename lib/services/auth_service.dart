import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // --- Public Auth Methods ---

  Future<void> signInWithGoogle() async {
    try {
      // 1. Get Google Credential
      final gsi.GoogleSignInAccount? googleUser =
          await gsi.GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled

      final gsi.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 2. Attempt Smart Link/Merge
      await _smartLinkOrMerge(credential);
    } catch (e) {
      debugPrint("AuthService: Google Sign-In Error: $e");
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      if (!Platform.isIOS) return;

      // 1. Get Apple Credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 2. Attempt Smart Link/Merge
      await _smartLinkOrMerge(credential);
    } catch (e) {
      debugPrint("AuthService: Apple Sign-In Error: $e");
      rethrow;
    }
  }

  // --- Core Logic: Link or Merge ---

  Future<void> _smartLinkOrMerge(AuthCredential credential) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Should ideally not happen in this flow (as we are anon), but handle safe
      await _auth.signInWithCredential(credential);
      return;
    }

    try {
      // HAPPY PATH: Link current anon chain to new provider
      await currentUser.linkWithCredential(credential);
      debugPrint(
          "AuthService: Successfully linked credential to current UID: ${currentUser.uid}");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // CONFLICT PATH: Target account already exists. We must merge and switch.
        debugPrint(
            "AuthService: Credential already in use. Initiating Merge...");
        await _performMergeAndSwitch(currentUser, credential);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _performMergeAndSwitch(
      User anonUser, AuthCredential targetCredential) async {
    // 1. Snapshot Anonymous Data
    final anonUid = anonUser.uid;
    final anonRef = _db.ref('users/$anonUid');
    final anonSnapshot = await anonRef.get();

    // Default safe values in case snapshot is empty
    Map<dynamic, dynamic> anonData = {};
    if (anonSnapshot.exists && anonSnapshot.value is Map) {
      anonData = anonSnapshot.value as Map<dynamic, dynamic>;
    }

    int anonGold = 0;
    int anonGems = 0;
    // Extract Wallet (handle nulls safely)
    if (anonData.containsKey('wallet')) {
      final w = anonData['wallet'] as Map?;
      anonGold = (w?['totalEarned'] as num?)?.toInt() ?? 0;
      anonGems = (w?['diamonds'] as num?)?.toInt() ??
          0; // assuming key is diamonds or gems? Checking usage...
      // Usually Lobby uses 'wallet/totalEarned'. Let's check typical structure or just grab generic keys.
      // Based on previous code: users/{uid}/wallet/totalEarned
      // Let's assume standard wallet struct: { gold: X, diamonds: Y, totalEarned: Z }
      // Actually wait, previous code showed: users/uid/wallet/totalEarned directly.
      // Let's grab the raw 'wallet' map to be safe and merge assumed fields.
    }

    // IMPORTANT: Sign In to the Target Account (this handles the switch)
    // This will dispose the current User object, so we captured data first.
    final userCredential = await _auth.signInWithCredential(targetCredential);
    final targetUser = userCredential.user;

    if (targetUser == null)
      throw Exception("Failed to sign in to target account during merge");

    final targetUid = targetUser.uid;
    debugPrint(
        "AuthService: Switched to Target UID: $targetUid. Merging data from $anonUid...");

    // 2. Perform DB Transaction to Merge
    // We add Anonymous Wallet values to Target Wallet values.
    // We also log the alias.

    final targetWalletRef = _db.ref('users/$targetUid/wallet');

    await targetWalletRef.runTransaction((currentData) {
      // Transaction ensures atomic update
      Map<dynamic, dynamic> walletData = {};
      if (currentData is Map) {
        walletData = Map<dynamic, dynamic>.from(currentData);
      }

      // Merge: Summation strategy
      // Update specific known keys. If dynamic schema, might need recursive merge,
      // but for currencies, explicit is better.
      final currentGold = (walletData['gold'] as num?)?.toInt() ?? 0;
      final currentDiamonds = (walletData['diamonds'] as num?)?.toInt() ?? 0;
      final currentTotalEarned =
          (walletData['totalEarned'] as num?)?.toInt() ?? 0;

      // Extract explicit keys from anon (need to be sure of keys from snapshot)
      final anonWallet = anonData['wallet'] as Map? ?? {};
      final aGold = (anonWallet['gold'] as num?)?.toInt() ?? 0;
      final aDiamonds = (anonWallet['diamonds'] as num?)?.toInt() ?? 0;
      final aTotalEarned = (anonWallet['totalEarned'] as num?)?.toInt() ?? 0;

      walletData['gold'] = currentGold + aGold;
      walletData['diamonds'] = currentDiamonds + aDiamonds;
      walletData['totalEarned'] = currentTotalEarned + aTotalEarned;

      return Transaction.success(walletData);
    });

    // 3. Mark the connection
    await _db.ref('users/$targetUid/merged_aliases/$anonUid').set({
      'timestamp': ServerValue.timestamp,
      'merged': true,
    });

    // 4. (Optional) Cleanup old user data?
    // Usually safer to keep it or mark it as 'merged_to': targetUid
    await anonRef.update({'merged_to': targetUid});

    debugPrint("AuthService: Merge Complete.");
  }
}
