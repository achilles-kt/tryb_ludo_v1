import 'package:flutter/material.dart';
import '../../../utils/image_utils.dart';

class AvatarSelectorGrid extends StatelessWidget {
  final List<String> avatars;
  final String selectedAvatar;
  final ValueChanged<String> onAvatarSelected;

  const AvatarSelectorGrid({
    super.key,
    required this.avatars,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF181B21);
    const primary = Color(0xFF3B82F6);
    const textMuted = Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CHOOSE YOUR AVATAR",
              style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: avatars.length,
            itemBuilder: (context, index) {
              final asset = avatars[index];
              final isSelected = asset == selectedAvatar;
              return GestureDetector(
                onTap: () => onAvatarSelected(asset),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: primary, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: primary.withValues(alpha: 0.5),
                                blurRadius: 12)
                          ]
                        : null,
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF111318),
                    backgroundImage: ImageUtils.getAvatarProvider(asset),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
