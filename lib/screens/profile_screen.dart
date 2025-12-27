import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/level_badge.dart';
import '../utils/level_calculator.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Not Logged In"));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Profile Header
              Center(child: _buildProfileHeader(user)),
              const SizedBox(height: 32),

              // Stats Grid
              _buildStatsGrid(user.uid),
              const SizedBox(height: 24),

              // Settings / Menu
              _buildMenuOption(Icons.settings, "Settings", () {}),
              _buildMenuOption(Icons.help_outline, "Help & Support", () {}),
              _buildMenuOption(Icons.logout, "Logout", () async {
                await FirebaseAuth.instance.signOut();
                // App will likely reload or handle auth state change elsewhere
              }, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return StreamBuilder<DatabaseEvent>(
        stream:
            FirebaseDatabase.instance.ref('users/${user.uid}/profile').onValue,
        builder: (context, snapshot) {
          final data = snapshot.data?.snapshot.value as Map?;
          final name = data?['displayName'] ?? user.displayName ?? 'Player';
          final avatar = data?['avatarUrl'] ?? 'assets/avatars/a1.png';
          final city = data?['city'] ?? 'Unknown City';

          return Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGrad,
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.neonBlue.withOpacity(0.4),
                              blurRadius: 20)
                        ]),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: avatar.startsWith('http')
                          ? NetworkImage(avatar)
                          : AssetImage(avatar) as ImageProvider,
                    ),
                  ),
                  // Edit Icon
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: AppTheme.bgDark, shape: BoxShape.circle),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: AppTheme.neonBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text(name, style: AppTheme.header.copyWith(fontSize: 24)),
              Text(city, style: AppTheme.label.copyWith(color: Colors.white54)),
            ],
          );
        });
  }

  Widget _buildStatsGrid(String uid) {
    return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$uid/wallet').onValue,
        builder: (context, snapshot) {
          final wallet = snapshot.data?.snapshot.value as Map?;
          final totalEarned = (wallet?['totalEarned'] as num?)?.toInt() ?? 0;
          final games = (wallet?['gamesPlayed'] as num?)?.toInt() ?? 0;

          final levelInfo = LevelCalculator.calculate(totalEarned);

          return Column(
            children: [
              // Level Banner
              SizedBox(
                width: double.infinity,
                child: GlassContainer(
                  color: AppTheme.neonBlue.withOpacity(0.1),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      LevelBadge(level: levelInfo.level, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Level ${levelInfo.level}",
                                style: AppTheme.text
                                    .copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: levelInfo.progress,
                              backgroundColor: Colors.white10,
                              color: AppTheme.neonBlue,
                              minHeight: 4,
                            ),
                            const SizedBox(height: 4),
                            Text(levelInfo.levelTitle,
                                style: AppTheme.label.copyWith(fontSize: 10))
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _statCard("Total Won", "$totalEarned",
                          Icons.monetization_on, AppTheme.gold)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _statCard("Games Played", "$games",
                          Icons.sports_esports, AppTheme.neonBlue)),
                ],
              )
            ],
          );
        });
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: AppTheme.header.copyWith(fontSize: 20)),
          Text(label, style: AppTheme.label.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10))),
        child: Row(
          children: [
            Icon(icon,
                color: isDestructive ? AppTheme.neonRed : Colors.white70),
            const SizedBox(width: 16),
            Text(title,
                style: AppTheme.text.copyWith(
                    color: isDestructive ? AppTheme.neonRed : Colors.white)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30)
          ],
        ),
      ),
    );
  }
}
