import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/location_service.dart';
import '../utils/level_calculator.dart';
import '../widgets/level_badge.dart';

class UserProfileHeader extends StatefulWidget {
  final User? currentUser;
  final Function(String name, String avatar, String city, String country)
      onProfileTap;

  const UserProfileHeader({
    Key? key,
    required this.currentUser,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  State<UserProfileHeader> createState() => _UserProfileHeaderState();
}

class _UserProfileHeaderState extends State<UserProfileHeader> {
  bool _hasAttemptedLocationFetch = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('users/${widget.currentUser?.uid}/profile')
                .onValue,
            builder: (context, snapshot) {
              final data = snapshot.data?.snapshot.value as Map?;
              final name = data?['displayName'] as String? ?? 'New User';
              final avatar =
                  data?['avatarUrl'] as String? ?? 'assets/avatars/a1.png';

              // Extract raw values to check if they are actually empty in DB
              final rawCity = data?['city']?.toString() ?? '';
              final rawCountry = data?['country']?.toString() ?? '';

              // UI Display values (with defaults)
              final displayCity = rawCity;
              final displayCountry = rawCountry.isEmpty ? 'India' : rawCountry;

              final location = displayCity.isEmpty
                  ? displayCountry
                  : '$displayCity, $displayCountry';

              // Auto-fetch location if RAW values are missing
              if ((rawCity.isEmpty || rawCountry.isEmpty) &&
                  !_hasAttemptedLocationFetch &&
                  widget.currentUser != null) {
                _hasAttemptedLocationFetch = true;
                LocationService.fetchCityCountry().then((locData) {
                  if (locData != null && mounted) {
                    FirebaseDatabase.instance
                        .ref('users/${widget.currentUser!.uid}/profile')
                        .update({
                      if (rawCity.isEmpty) 'city': locData['city'],
                      if (rawCountry.isEmpty) 'country': locData['country'],
                    });
                  }
                });
              }

              return StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref(
                          'users/${widget.currentUser?.uid}/wallet/totalEarned')
                      .onValue,
                  builder: (context, walletSnap) {
                    final totalGold =
                        (walletSnap.data?.snapshot.value as num?)?.toInt() ?? 0;
                    final levelInfo = LevelCalculator.calculate(totalGold);

                    return GestureDetector(
                      behavior: HitTestBehavior
                          .opaque, // Ensures the entire area is tappable
                      onTap: () => widget.onProfileTap(
                          name, avatar, displayCity, displayCountry),
                      child: Row(children: [
                        Stack(children: [
                          Hero(
                            tag: 'lobby_avatar',
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(avatar,
                                    width: 48, height: 48, fit: BoxFit.cover)),
                          ),
                          // Level Badge Overlay (Small)
                          Positioned(
                              bottom: -4,
                              right: -4,
                              child: LevelBadge(
                                  level: levelInfo.level,
                                  size: 24,
                                  showLabel: false)),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                // Level
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Text("LVL ${levelInfo.level}",
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold))),
                                const SizedBox(height: 2),
                                // Location
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 10,
                                        color: Colors.white.withOpacity(0.6)),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(location,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: const Color(0xFF94A3B8))),
                                    ),
                                  ],
                                ),
                              ]),
                        )
                      ]),
                    );
                  });
            }));
  }
}
