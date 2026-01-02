import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_profile_service.dart';
import '../../utils/level_calculator.dart';
import '../../utils/country_utils.dart';
import '../profile/edit/avatar_selector_grid.dart';
import '../profile/level_progress_card.dart';
import '../profile/edit/phone_verification_display.dart';
import '../profile/edit/profile_identity_form.dart';
import '../../controllers/profile_auth_controller.dart';
import '../profile/profile_bottom_actions.dart';
import '../../services/conversion_service.dart'; // Import NudgeType

class ProfileEditModal extends StatefulWidget {
  final String currentName;
  final String currentAvatar;
  final String currentCity;
  final String currentCountry;
  final VoidCallback? onSave;
  final NudgeType nudgeType; // New param

  const ProfileEditModal({
    super.key,
    this.currentName = '',
    this.currentAvatar = 'assets/avatars/a1.png',
    this.currentCity = '',
    this.currentCountry = '',
    this.onSave,
    this.nudgeType = NudgeType.none, // Default none
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

  late String _selectedAvatar;
  bool _isSaving = false;
  LevelInfo? _levelInfo;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _avatarSectionKey = GlobalKey();

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

  final ProfileAuthController _authController = ProfileAuthController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _cityController = TextEditingController(text: widget.currentCity);
    _countryController = TextEditingController(text: widget.currentCountry);
    _selectedAvatar = widget.currentAvatar;

    _authController.addListener(() {
      if (mounted) setState(() {});
    });
    _authController.init(FirebaseAuth.instance.currentUser);

    _initData();
  }

  Future<void> _initData() async {
    _fetchLevelInfo();
    // Always fetch latest profile data to ensure form is current, unless provided
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

  Future<void> _fetchLevelInfo() async {
    final info = await UserProfileService.instance.fetchLevelInfo();
    if (mounted && info != null) {
      setState(() => _levelInfo = info);
    }
  }

  // Helper to autofill if needed (pure UI)
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
    _authController.dispose();
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
      String? gender;
      if (_selectedAvatar.contains('assets/avatars/')) {
        // Logic: a1-a4 = Female, a5-a8 = Male
        if (_selectedAvatar.contains('a1.png') ||
            _selectedAvatar.contains('a2.png') ||
            _selectedAvatar.contains('a3.png') ||
            _selectedAvatar.contains('a4.png')) {
          gender = 'female';
        } else if (_selectedAvatar.contains('a5.png') ||
            _selectedAvatar.contains('a6.png') ||
            _selectedAvatar.contains('a7.png') ||
            _selectedAvatar.contains('a8.png')) {
          gender = 'male';
        }
      }

      await UserProfileService.instance.updateProfile(
        name: _nameController.text.trim(),
        avatar: _selectedAvatar,
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        gender: gender,
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

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1115);

    final isAnon =
        !_authController.isGoogleLinked && !_authController.isAppleLinked;
    final isLoading = _isSaving || _authController.isLoading;

    // --- Heading Logic ---
    String title = "EDIT PROFILE";
    String? subtext;
    IconData? titleIcon;
    Color titleColor = Colors.white;

    if (widget.nudgeType == NudgeType.soft) {
      title = "SAVE PROGRESS";
      subtext = "Sign Up to Play across devices.";
      titleIcon = Icons.cloud_upload;
      titleColor = Colors.lightBlueAccent;
    } else if (widget.nudgeType == NudgeType.hard) {
      title = "DON'T LOSE PROGRESS";
      subtext = "Sign Up to Play across devices.";
      titleIcon = Icons.lock_outline; // or GppGood
      titleColor = Colors.amberAccent;
    }

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
            border: widget.nudgeType != NudgeType.none
                ? Border.all(color: titleColor.withOpacity(0.3), width: 1.5)
                : null,
            boxShadow: widget.nudgeType != NudgeType.none
                ? [
                    BoxShadow(
                        color: titleColor.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ]
                : [],
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
                    // If Nudge, show Icon
                    if (titleIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(titleIcon, color: titleColor, size: 20),
                      )
                    else
                      const SizedBox(width: 24),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  color: titleColor,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700)),
                          if (subtext != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtext,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            )
                        ],
                      ),
                    ),
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
                    // 1. Profile Identity Form
                    ProfileIdentityForm(
                      nameController: _nameController,
                      cityController: _cityController,
                      countryController: _countryController,
                      selectedAvatar: _selectedAvatar,
                      levelInfo: _levelInfo,
                      onAvatarTap: _scrollToAvatars,
                    ),
                    const SizedBox(height: 16),

                    LevelProgressCard(levelInfo: _levelInfo),

                    const SizedBox(height: 16),

                    PhoneVerificationDisplay(
                        linkedPhoneNumber: _authController.linkedPhoneNumber,
                        codeSent: _authController.codeSent,
                        isSaving: isLoading,
                        phoneController: _phoneController,
                        otpController: _otpController,
                        onSendCode: () async {
                          final p = _phoneController.text.trim();
                          if (p.isEmpty) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _authController.sendOtp(p);
                          } catch (e) {
                            messenger.showSnackBar(
                                SnackBar(content: Text("Error: $e")));
                          }
                        },
                        onVerifyOtp: () async {
                          final o = _otpController.text.trim();
                          if (o.isEmpty) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _authController.verifyOtp(o);
                            _phoneController.clear();
                            _otpController.clear();
                            messenger.showSnackBar(
                                SnackBar(content: Text("Phone Linked!")));
                          } catch (e) {
                            messenger.showSnackBar(
                                SnackBar(content: Text("Error: $e")));
                          }
                        },
                        onChangeNumber: () {
                          _authController.resetPhoneState();
                          _phoneController.clear();
                          _otpController.clear();
                          _tryAutoFillCountryCode();
                        }),

                    const SizedBox(height: 16),

                    // Avatar Picker (with key for scrolling)
                    Container(
                      key: _avatarSectionKey,
                      child: AvatarSelectorGrid(
                        avatars: _avatars,
                        selectedAvatar: _selectedAvatar,
                        onAvatarSelected: (val) =>
                            setState(() => _selectedAvatar = val),
                      ),
                    ),

                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: ProfileBottomActions(
          isAnon: isAnon,
          isLoading: isLoading,
          nudgeType: widget.nudgeType, // Pass it down
          onGoogleTap: () => _authController.linkGoogle(),
          onAppleTap: () => _authController.linkApple(),
          onSaveTap: _handleSave,
          onLogout: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pop(context);
          }),
    );
  }
}
