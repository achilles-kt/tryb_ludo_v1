import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../widgets/level_badge.dart';
import '../utils/level_calculator.dart';

class ProfileEditModal extends StatefulWidget {
  final String currentName;
  final String currentAvatar;
  final String currentCity;
  final String currentCountry;
  final VoidCallback? onSave;

  const ProfileEditModal({
    super.key,
    required this.currentName,
    required this.currentAvatar,
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
  late String _selectedAvatar;
  bool _isSaving = false;
  LevelInfo? _levelInfo;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _avatarSectionKey = GlobalKey();

  bool _isGoogleLinked = false;
  bool _isAppleLinked = false;

  // Placeholder for Indian Avatars (4M, 4F)
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
    _fetchLevelInfo();
    _checkLinkedProviders();
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/$uid/wallet/totalEarned')
          .get();

      final totalGold = (snap.value as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() {
          _levelInfo = LevelCalculator.calculate(totalGold);
        });
      }
    } catch (e) {
      debugPrint("Error fetching level info: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAvatars() {
    if (_avatarSectionKey.currentContext != null) {
      Scrollable.ensureVisible(_avatarSectionKey.currentContext!,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      // Fallback
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseDatabase.instance.ref('users/$uid/profile').update({
        'displayName': _nameController.text.trim(),
        'avatarUrl': _selectedAvatar,
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'updatedAt': ServerValue.timestamp,
      });

      if (mounted) {
        widget.onSave?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Auth Handlers ---

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isSaving = true);
      await AuthService.instance.signInWithGoogle();
      if (mounted) {
        // Refresh link status and likely reload profile if user switched
        _checkLinkedProviders();
        // Optionally close modal or show success?
        // If merge happened, the entire app state might need refresh.
        // But for now, just updating UI state effectively changes buttons.
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Google Sign In Failed: $e")));
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Apple Sign In Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1115);
    const cardBg = Color(0xFF181B21);
    const primary = Color(0xFF3B82F6);
    const gold = Color(0xFFFACC15);
    const textMuted = Color(0xFF9CA3AF);

    // Determine if we show Auth Buttons
    // Rule: "If only anonymous -> show buttons as Primary. Save is Secondary."
    // Rule: "If linked -> Save is Primary."
    final isAnon = !_isGoogleLinked && !_isAppleLinked;

    return Scaffold(
      backgroundColor: Colors.black54, // Overlay dimming
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width > 420
              ? 390
              : MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height *
              0.90, // Slightly taller for auth buttons
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
                    const SizedBox(width: 24), // Spacer for centering title
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
                        decoration: BoxDecoration(
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
                          // Avatar
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

                          // Name Field
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

                          // Handle (mock derived from name)
                          Text(
                              "@${_nameController.text.toLowerCase().replaceAll(' ', '_')}",
                              style: TextStyle(color: textMuted, fontSize: 13)),

                          const SizedBox(height: 20),

                          // City and Country Row
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
                                    style: TextStyle(
                                        color: gold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Progress Card
                    if (_levelInfo != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("LEVEL PROGRESS",
                                style: TextStyle(
                                    color: textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _levelInfo!.progress,
                                minHeight: 10,
                                backgroundColor: const Color(0xFF0B0D11),
                                color: gold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                                "${_levelInfo!.totalGold} / ${_levelInfo!.nextThreshold} XP",
                                style:
                                    TextStyle(color: textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 3. Avatar Picker Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        key: _avatarSectionKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CHOOSE YOUR AVATAR",
                              style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _avatars.length,
                            itemBuilder: (context, index) {
                              final asset = _avatars[index];
                              final isSelected = asset == _selectedAvatar;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedAvatar = asset),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: primary, width: 3)
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: primary.withOpacity(0.5),
                                                blurRadius: 12)
                                          ]
                                        : null,
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: const Color(0xFF111318),
                                    backgroundImage: AssetImage(asset),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // Space for bottom bar
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
            // PRIMARY BUTTON AREA
            if (isAnon) ...[
              // Row for Providers
              Row(
                children: [
                  // Google Button (Primary on Android, Left on iOS)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.login,
                          color: Colors
                              .black), // Ideal: proper Google G Logo asset
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

                  // Apple Button (Only on iOS)
                  if (Platform.isIOS) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleAppleSignIn,
                      // Ideal: Apple Logo
                      child: const Icon(Icons.apple,
                          color: Colors.white, size: 28),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white24)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // SECONDARY: Save & Continue (Text/Outlined)
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
              // LINKED STATE: Save is Primary
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
            ]
          ],
        ),
      ),
    );
  }
}
