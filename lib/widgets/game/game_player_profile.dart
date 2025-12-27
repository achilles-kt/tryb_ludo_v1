import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';
import '../../utils/level_calculator.dart';

class GamePlayerProfile extends StatefulWidget {
  final String uid;
  final String fallbackName;
  final String? fallbackAvatar;
  final bool isMe;
  final bool isTurn;
  final bool isTeam;
  final Color? teamColor;

  const GamePlayerProfile({
    Key? key,
    required this.uid,
    required this.fallbackName,
    this.fallbackAvatar,
    this.isMe = false,
    this.isTurn = false,
    this.isTeam = false,
    this.teamColor,
  }) : super(key: key);

  @override
  State<GamePlayerProfile> createState() => _GamePlayerProfileState();
}

class _GamePlayerProfileState extends State<GamePlayerProfile> {
  // Use streams to fetch data

  @override
  Widget build(BuildContext context) {
    if (widget.uid == 'bot' || widget.uid.startsWith('bot-')) {
      return _buildStaticBadge(
          widget.fallbackName, widget.fallbackAvatar, 1, "AI City");
    }

    return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/${widget.uid}').onValue,
        builder: (context, snapshot) {
          String name = widget.fallbackName;
          String avatar = widget.fallbackAvatar ?? 'assets/avatars/a1.png';
          String location = "Earth";
          int totalEarned = 0;

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map?;
            if (data != null) {
              final profile = data['profile'] as Map?;
              final wallet = data['wallet'] as Map?;

              if (profile != null) {
                name = profile['displayName'] ?? name;
                avatar = profile['avatarUrl'] ?? avatar;
                // Location format: "City, Country" -> just show City
                location = profile['city'] ?? "Unknown";
              }
              if (wallet != null) {
                totalEarned = (wallet['totalEarned'] as num?)?.toInt() ?? 0;
              }
            }
          }

          final levelInfo = LevelCalculator.calculate(totalEarned);
          return _buildStaticBadge(name, avatar, levelInfo.level, location);
        });
  }

  Widget _buildStaticBadge(
      String name, String? avatarUrl, int level, String location) {
    final borderColor = widget.isTurn
        ? AppTheme.gold
        : (widget.isTeam
            ? (widget.teamColor ?? AppTheme.neonBlue)
            : Colors.white24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + Level
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: borderColor, width: widget.isTurn ? 2.5 : 1.5),
                  boxShadow: widget.isTurn
                      ? [const BoxShadow(color: AppTheme.gold, blurRadius: 12)]
                      : null,
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
                right: -4,
                bottom: -4,
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
        const SizedBox(height: 6),

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
              Text(location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 8)),
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
