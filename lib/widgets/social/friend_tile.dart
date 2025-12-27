import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../glass_container.dart';

enum FriendStatus { online, offline, playing }

class FriendTile extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final FriendStatus status;
  final String statusText; // e.g. "Online" or "Playing 2P..."
  final VoidCallback onTap;
  final VoidCallback onChat;

  const FriendTile({
    Key? key,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.statusText,
    required this.onTap,
    required this.onChat,
  }) : super(key: key);

  Color get _statusColor {
    switch (status) {
      case FriendStatus.online:
        return AppTheme.neonGreen;
      case FriendStatus.playing:
        return AppTheme.gold;
      case FriendStatus.offline:
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white.withOpacity(0.03),
          borderColor: Colors.white.withOpacity(0.08),
          child: Row(
            children: [
              // Avatar Box
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image(
                        image: avatarUrl.startsWith('http')
                            ? NetworkImage(avatarUrl)
                            : AssetImage(avatarUrl) as ImageProvider,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (status != FriendStatus.offline)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0F1218), // Match bgDark
                            width: 2.5,
                          ),
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                          color: status == FriendStatus.offline
                              ? Colors.white38
                              : _statusColor,
                          fontSize: 11,
                          fontWeight: status == FriendStatus.playing
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                children: [
                  _iconBtn(Icons.chat_bubble_outline, Colors.white54, onChat),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
