import 'package:flutter/material.dart';
import '../../utils/image_utils.dart';
import '../../theme/app_theme.dart';
import '../common/glass_container.dart';

class FriendSuggestionCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String contextText; // e.g. "Mutual Friend"
  final VoidCallback onAccept;
  final VoidCallback onDeny;
  final bool showActions;

  const FriendSuggestionCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.contextText,
    required this.onAccept,
    required this.onDeny,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, // Clean fixed width
      margin: const EdgeInsets.only(right: 12),
      child: GlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        color: Colors.white.withOpacity(0.03), // Subtle glass
        borderColor: Colors.white.withOpacity(0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF333333),
                backgroundImage: avatarUrl.startsWith('http')
                    ? NetworkImage(avatarUrl)
                    : ImageUtils.getAvatarProvider(avatarUrl),
              ),
            ),
            const SizedBox(height: 6),

            // Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),

            // Context
            Text(
              contextText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 10),

            // Actions
            if (showActions)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(Icons.check, AppTheme.neonGreen, onAccept),
                  const SizedBox(width: 8),
                  _actionBtn(Icons.close, AppTheme.neonRed, onDeny),
                ],
              )
            else
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child:
                      Icon(Icons.access_time, color: Colors.white30, size: 20))
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
