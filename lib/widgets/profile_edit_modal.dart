import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../utils/level_calculator.dart';
import '../utils/country_utils.dart';
import 'profile/avatar_picker.dart';
import 'profile/level_progress_card.dart';
import 'profile/phone_linking_card.dart';
import '../widgets/level_badge.dart';

class ProfileEditModal extends StatefulWidget {
  final String currentName;
  final String currentAvatar;
  final String currentCity;
  final String currentCountry;
  final VoidCallback? onSave;

  const ProfileEditModal({
    super.key,
    this.currentName = '',
    this.currentAvatar = 'assets/avatars/a1.png',
    this.currentCity = '',
    this.currentCountry = '',
    this.onSave,
  });

  @override
  State<ProfileEditModal> createState() => _ProfileEditModalState();
}

class _ProfileEditModalState extends State<ProfileEditModal> {
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _countryController;

  // Phone Auth
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  String? _linkedPhoneNumber;

  late String _selectedAvatar;
  bool _isSaving = false;
  LevelInfo? _levelInfo;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _avatarSectionKey = GlobalKey();

  bool _isGoogleLinked = false;
  bool _isAppleLinked = false;

  final List<String> _avatars = [
    'assets/avatars/a1.png',
    'assets/avatars/a2.png',
    'assets/avatars/a3.png',
    'assets/avatars/a4.png',
    'assets/avatars/a5.png',
    'assets/avatars/a6.png',
    'assets/avatars/a7.png',
    'assets/avatars/a8.png'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _cityController = TextEditingController(text: widget.currentCity);
    _countryController = TextEditingController(text: widget.currentCountry);
    _selectedAvatar = widget.currentAvatar;

    _initData();
  }

  Future<void> _initData() async {
    _fetchLevelInfo();
    _fetchLinkedPhone();
    _checkLinkedProviders();
    if (widget.currentName.isEmpty) {
      _fetchProfileData();
    }
  }

  Future<void> _fetchProfileData() async {
    final p = await UserProfileService.instance.fetchProfile();
    if (p != null && mounted) {
      setState(() {
        _nameController.text = p['displayName'] ?? '';
        _cityController.text = p['city'] ?? '';
        _countryController.text = p['country'] ?? '';
        if (p['avatarUrl'] != null && (p['avatarUrl'] as String).isNotEmpty) {
          _selectedAvatar = p['avatarUrl'];
        }
      });
    }
  }

  void _checkLinkedProviders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (var p in user.providerData) {
        if (p.providerId == 'google.com') _isGoogleLinked = true;
        if (p.providerId == 'apple.com') _isAppleLinked = true;
      }
    }
  }

  Future<void> _fetchLevelInfo() async {
    final info = await UserProfileService.instance.fetchLevelInfo();
    if (mounted && info != null) {
      setState(() => _levelInfo = info);
    }
  }

  Future<void> _fetchLinkedPhone() async {
    final data = await UserProfileService.instance.fetchLinkedPhone();
    if (data != null && data['verified'] == true) {
      if (mounted)
        setState(() => _linkedPhoneNumber = data['number'] as String?);
    } else {
      _tryAutoFillCountryCode();
    }
  }

  Future<void> _tryAutoFillCountryCode() async {
    if (_phoneController.text.isNotEmpty) return;
    final code = await CountryUtils.fetchCountryDialCode();
    if (code != null && mounted && _phoneController.text.isEmpty) {
      setState(() => _phoneController.text = "$code ");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAvatars() {
    if (_avatarSectionKey.currentContext != null) {
      Scrollable.ensureVisible(_avatarSectionKey.currentContext!,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      await UserProfileService.instance.updateProfile(
        name: _nameController.text.trim(),
        avatar: _selectedAvatar,
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
      );

      if (mounted) {
        widget.onSave?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isSaving = true);
      await AuthService.instance.signInWithGoogle();
      if (mounted) _checkLinkedProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Google Sign In Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => _isSaving = true);
      await AuthService.instance.signInWithApple();
      if (mounted) _checkLinkedProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Apple Sign In Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Phone Auth Logic ---

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter a phone number")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService.instance.verifyPhoneNumber(
          phoneNumber: phone,
          onCodeSent: (verId) {
            if (mounted) {
              setState(() {
                _verificationId = verId;
                _codeSent = true;
                _isSaving = false;
              });
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("OTP Sent!")));
            }
          },
          onFail: (err) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("Error: $err")));
            }
          },
          onAutoVerify: (cred) async {
            // Android Auto-verify
          });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        debugPrint("Phone err: $e");
      }
    }
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _otpController.text.trim();
    if (_verificationId == null || otp.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await AuthService.instance.linkPhoneCredential(_verificationId!, otp);
      await UserProfileService.instance
          .linkPhoneNumber(number: _phoneController.text.trim());

      if (mounted) {
        setState(() {
          _isSaving = false;
          _codeSent = false;
          _linkedPhoneNumber = _phoneController.text.trim();
          _phoneController.clear();
          _otpController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Phone Linked Successfully!")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Invalid OTP: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1115);
    const cardBg = Color(0xFF181B21);
    const primary = Color(0xFF3B82F6);
    const gold = Color(0xFFFACC15);
    const textMuted = Color(0xFF9CA3AF);

    final isAnon = !_isGoogleLinked && !_isAppleLinked;

    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width > 420
              ? 390
              : MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.90,
          margin: const EdgeInsets.only(top: 40),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Text("EDIT PROFILE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // 1. Profile Identity Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _scrollToAvatars,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF60A5FA),
                                    Color(0xFF9333EA)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cardBg,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    _selectedAvatar,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _scrollToAvatars,
                            child: const Text("✨ Change Avatar",
                                style: TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Enter Name",
                              hintStyle: TextStyle(color: Colors.white24),
                              isDense: true,
                            ),
                          ),
                          Text(
                              "@${_nameController.text.toLowerCase().replaceAll(' ', '_')}",
                              style: const TextStyle(
                                  color: textMuted, fontSize: 13)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: TextField(
                                    controller: _cityController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "City",
                                        hintStyle:
                                            TextStyle(color: Colors.white24),
                                        isDense: true,
                                        icon: Icon(Icons.location_city,
                                            size: 14, color: Colors.white24)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: TextField(
                                    controller: _countryController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Country",
                                        hintStyle:
                                            TextStyle(color: Colors.white24),
                                        isDense: true,
                                        icon: Icon(Icons.public,
                                            size: 14, color: Colors.white24)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_levelInfo != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LevelBadge(
                                    level: _levelInfo!.level,
                                    size: 20,
                                    showLabel: false),
                                const SizedBox(width: 6),
                                Text("LVL ${_levelInfo!.level} · Rookie",
                                    style: const TextStyle(
                                        color: gold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    LevelProgressCard(levelInfo: _levelInfo),

                    const SizedBox(height: 16),

                    PhoneLinkingCard(
                        linkedPhoneNumber: _linkedPhoneNumber,
                        codeSent: _codeSent,
                        isSaving: _isSaving,
                        phoneController: _phoneController,
                        otpController: _otpController,
                        onSendCode: _handleSendCode,
                        onVerifyOtp: _handleVerifyOTP,
                        onChangeNumber: () {
                          setState(() {
                            _linkedPhoneNumber = null;
                            _codeSent = false;
                            _phoneController.clear();
                            _tryAutoFillCountryCode();
                          });
                        }),

                    const SizedBox(height: 16),

                    // Avatar Picker (with key for scrolling)
                    Container(
                      key: _avatarSectionKey,
                      child: AvatarPicker(
                        avatars: _avatars,
                        selectedAvatar: _selectedAvatar,
                        onAvatarSelected: (val) =>
                            setState(() => _selectedAvatar = val),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: bg,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAnon) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.login, color: Colors.black),
                      label: const Text("Continue with Google",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (Platform.isIOS) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleAppleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white24)),
                      ),
                      child: const Icon(Icons.apple,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: const Text("Save locally & Continue",
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Save & Continue →",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],

            // LOGOUT BUTTON
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout, size: 16, color: Colors.white30),
                label: const Text("Logout",
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
