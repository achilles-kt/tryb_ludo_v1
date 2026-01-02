import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';

class ProfileAuthController extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  // State
  bool _isGoogleLinked = false;
  bool _isAppleLinked = false;
  String? _linkedPhoneNumber;

  bool _codeSent = false;
  String? _verificationId;
  String? _pendingPhoneNumber;
  bool _isLoading = false;

  // Getters
  bool get isGoogleLinked => _isGoogleLinked;
  bool get isAppleLinked => _isAppleLinked;
  String? get linkedPhoneNumber => _linkedPhoneNumber;
  bool get codeSent => _codeSent;
  bool get isLoading => _isLoading;

  void init(User? user) {
    if (user != null) {
      _checkLinkedProviders(user);
    }
  }

  void _checkLinkedProviders(User user) {
    _isGoogleLinked = false;
    _isAppleLinked = false;
    _linkedPhoneNumber = null;

    for (final p in user.providerData) {
      if (p.providerId == 'google.com') _isGoogleLinked = true;
      if (p.providerId == 'apple.com') _isAppleLinked = true;
      if (p.providerId == 'phone') _linkedPhoneNumber = p.phoneNumber;
    }
    notifyListeners();
  }

  // --- Actions ---

  Future<void> linkGoogle() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signInWithGoogle();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _checkLinkedProviders(user);
    } catch (e) {
      debugPrint("Google Link Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> linkApple() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signInWithApple();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _checkLinkedProviders(user);
    } catch (e) {
      debugPrint("Apple Link Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- Phone Auth ---

  Future<void> sendOtp(String phoneNumber) async {
    if (_isLoading) return;
    _setLoading(true);
    _pendingPhoneNumber = phoneNumber;
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verId) {
          _verificationId = verId;
          _codeSent = true;
          _setLoading(false);
        },
        onFail: (msg) {
          _setLoading(false);
          throw Exception(msg);
        },
        onAutoVerify: (cred) async {
          await _authService.linkCredential(cred);
          if (_pendingPhoneNumber != null) {
            await UserProfileService.instance
                .linkPhoneNumber(number: _pendingPhoneNumber!);
          }
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            _checkLinkedProviders(user);
            _resetPhoneState();
          }
          _setLoading(false);
        },
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    if (_verificationId == null) return;
    if (_isLoading) return;
    _setLoading(true);

    try {
      await _authService.linkPhoneCredential(_verificationId!, smsCode);
      if (_pendingPhoneNumber != null) {
        await UserProfileService.instance
            .linkPhoneNumber(number: _pendingPhoneNumber!);
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _checkLinkedProviders(user);
      _resetPhoneState();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void resetPhoneState() {
    _resetPhoneState();
    notifyListeners();
  }

  void _resetPhoneState() {
    _codeSent = false;
    _verificationId = null;
    _pendingPhoneNumber = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
