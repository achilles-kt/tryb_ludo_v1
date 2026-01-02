import 'package:flutter/material.dart';
import '../../../utils/level_calculator.dart';
import '../../../utils/image_utils.dart'; // Added
import '../../common/level_badge.dart';

class ProfileIdentityForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController cityController;
  final TextEditingController countryController;
  final String selectedAvatar;
  final LevelInfo? levelInfo;
  final VoidCallback onAvatarTap;

  const ProfileIdentityForm({
    super.key,
    required this.nameController,
    required this.cityController,
    required this.countryController,
    required this.selectedAvatar,
    this.levelInfo,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF181B21);
    const primary = Color(0xFF3B82F6);
    const gold = Color(0xFFFACC15);
    const textMuted = Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF9333EA)],
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
                  child: Image(
                    image: ImageUtils.getAvatarProvider(selectedAvatar),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAvatarTap,
            child: const Text("✨ Change Avatar",
                style: TextStyle(
                    color: primary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Enter Name",
              hintStyle: TextStyle(color: Colors.white24),
              isDense: true,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (context, value, child) {
              return Text("@${value.text.toLowerCase().replaceAll(' ', '_')}",
                  style: const TextStyle(color: textMuted, fontSize: 13));
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10)),
                  child: TextField(
                    controller: cityController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "City",
                        hintStyle: TextStyle(color: Colors.white24),
                        isDense: true,
                        icon: Icon(Icons.location_city,
                            size: 14, color: Colors.white24)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10)),
                  child: TextField(
                    controller: countryController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Country",
                        hintStyle: TextStyle(color: Colors.white24),
                        isDense: true,
                        icon: Icon(Icons.public,
                            size: 14, color: Colors.white24)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (levelInfo != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LevelBadge(level: levelInfo!.level, size: 20, showLabel: false),
                const SizedBox(width: 6),
                Text("LVL ${levelInfo!.level} · Rookie",
                    style: const TextStyle(
                        color: gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}
