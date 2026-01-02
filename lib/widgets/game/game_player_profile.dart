import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GamePlayerProfile extends StatefulWidget {
  final String uid;
  final String fallbackName;
  final String? fallbackAvatar;
  final int level;
  final String city;
  final bool isMe;
  final bool isTurn;
  final Color playerColor;
  final bool isTeammate;

  const GamePlayerProfile({
    super.key,
    required this.uid,
    required this.fallbackName,
    this.fallbackAvatar,
    this.level = 1,
    this.city = "Earth",
    this.isMe = false,
    this.isTurn = false,
    this.isTeammate = false,
    required this.playerColor,
  });

  @override
  State<GamePlayerProfile> createState() => _GamePlayerProfileState();
}

class _GamePlayerProfileState extends State<GamePlayerProfile> {
  @override
  Widget build(BuildContext context) {
    if (widget.uid == 'bot' || widget.uid.startsWith('bot-')) {
      return _buildStaticBadge(
          widget.fallbackName, widget.fallbackAvatar, 1, "AI City");
    }
    return _buildStaticBadge(
        widget.fallbackName, widget.fallbackAvatar, widget.level, widget.city);
  }

  Widget _buildStaticBadge(
      String name, String? avatarUrl, int level, String location) {
    // Core Logic per PRD
    // 1. Ring Color = Player Color (Always)
    final ringColor = widget.playerColor;

    // 2. Brightness (Turn Indicator)
    // Active Turn: Full Brightness, Thicker Ring
    // Inactive: Subdued (Opacity 0.6), Thinner Ring
    final ringOpacity = widget.isTurn ? 1.0 : 0.6;
    final ringWidth = widget.isTurn ? 3.0 : 1.5;

    // 3. Team Glow (2v2 only)
    // Behind Avatar, soft glow.
    // Explicitly behind ring.
    final List<BoxShadow> shadows = [];
    if (widget.isTeammate || (widget.isMe && widget.isTeammate)) {
      // Note: isTeammate implies "Is in my team".
      // If isMe is true, and I am in a team game, I should also glow?
      // PRD: "Glow is visible for: User, User’s teammate".
      // So yes, if I am in a team, I glow.
      // The caller passes 'isTeam' which usually means "Is this a team game AND in my team?".

      shadows.add(BoxShadow(
        color: Colors.white.withOpacity(0.4),
        blurRadius: 16,
        spreadRadius: 4,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + Level
        SizedBox(
          width: 56, // Slightly larger for glow space
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Team Glow (Layer 0) & Avatar (Layer 1) & Ring (Layer 2)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Layer 0: Shadow
                  boxShadow: shadows,
                  // Layer 2: Ring
                  border: Border.all(
                      color: ringColor.withOpacity(ringOpacity),
                      width: ringWidth),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.startsWith('http')
                      ? Image.network(avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackAvatar())
                      : Image.asset(avatarUrl ?? 'assets/avatars/a1.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackAvatar()),
                ),
              ),

              // Level Badge
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.neonBlue, width: 1)),
                  child: Text(
                    "Lv.$level",
                    style: const TextStyle(
                        color: AppTheme.neonBlue,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Name & Location
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black45, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Text(widget.isMe ? "YOU" : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              // Optional: Location text can be hidden if clutter is too high
            ],
          ),
        )
      ],
    );
  }

  Widget _fallbackAvatar() {
    return Image.asset('assets/avatars/a1.png', fit: BoxFit.cover);
  }
}
