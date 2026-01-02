import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';
// import '../../controllers/lobby_controller.dart'; // Removed unused
import '../../utils/image_utils.dart'; // Added import
import '../../utils/location_service.dart';
import '../../utils/level_calculator.dart';
import '../../utils/currency_formatter.dart';

class LobbyTopBar extends StatefulWidget {
  final User? currentUser;
  final Function(String name, String avatar, String city, String country)
      onProfileTap;

  const LobbyTopBar({
    super.key,
    required this.currentUser,
    required this.onProfileTap,
  });

  @override
  State<LobbyTopBar> createState() => _LobbyTopBarState();
}

class _LobbyTopBarState extends State<LobbyTopBar> {
  bool _hasAttemptedLocationFetch = false;

  // Assuming LobbyController is initialized and available,
  // or that the avatar logic needs to be adapted to existing widget.currentUser and avatar variable.
  // For this change, we'll assume a controller instance is needed to match the instruction's snippet.
  // In a real app, this controller would likely be provided via a Provider or similar state management.
  // For the purpose of this edit, we'll create a dummy one or adapt the logic.
  // Given the instruction's snippet, we'll adapt the logic to use existing `widget.currentUser` and `avatar` variable.
  // The instruction's snippet `controller.currentUser?.photoURL ?? controller.userAvatar`
  // implies a preference for `photoURL` from the User object, then a fallback.
  // We'll use `widget.currentUser?.photoURL` as the primary source, falling back to the `avatar` variable from Firebase.

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Profile Section (Left)
          Expanded(child: _buildProfileSection()),

          // 2. Wallet Section (Right)
          _buildWalletSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref('users/${widget.currentUser!.uid}/profile')
            .onValue,
        builder: (context, snapshot) {
          final data = snapshot.data?.snapshot.value as Map?;
          final name = data?['displayName'] as String? ?? 'New User';
          final avatar =
              data?['avatarUrl'] as String? ?? 'assets/avatars/a1.png';

          // Extract raw values
          final rawCity = data?['city']?.toString() ?? '';
          final rawCountry = data?['country']?.toString() ?? '';

          // UI values
          final displayCity = rawCity;
          final displayCountry = rawCountry.isEmpty ? 'India' : rawCountry;
          final location = displayCity.isEmpty
              ? displayCountry
              : '$displayCity, $displayCountry';

          // Auto-fetch location logic (Restored)
          if ((rawCity.isEmpty || rawCountry.isEmpty) &&
              !_hasAttemptedLocationFetch &&
              widget.currentUser != null) {
            _hasAttemptedLocationFetch = true;
            // Fire and forget fetch
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

          // Fetch Wallet Total for Level (Restored)
          return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('users/${widget.currentUser!.uid}/wallet/totalEarned')
                  .onValue,
              builder: (context, totalSnap) {
                final totalEarned =
                    (totalSnap.data?.snapshot.value as num?)?.toInt() ?? 0;
                final levelInfo = LevelCalculator.calculate(totalEarned);

                // Determine the avatar source, prioritizing Firebase User's photoURL
                // then falling back to the avatar from the database.
                final String avatarSource =
                    widget.currentUser?.photoURL ?? avatar;

                return InkWell(
                  onTap: () => widget.onProfileTap(
                      name, avatar, displayCity, displayCountry),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar Box with Level
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                                image: DecorationImage(
                                    image: ImageUtils.getAvatarProvider(
                                        avatarSource), // Changed line
                                    fit: BoxFit.cover)),
                          ),
                          Positioned(
                            bottom: -5,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppTheme.gold,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.bgDark, width: 2)),
                              child: Text(levelInfo.level.toString(),
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(location,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              });
        });
  }

  Widget _buildWalletSection() {
    return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref('users/${widget.currentUser!.uid}/wallet')
            .onValue,
        builder: (context, snapshot) {
          final data = snapshot.data?.snapshot.value as Map?;
          final gems = (data?['gems'] as num?)?.toInt() ?? 0;
          final gold = (data?['gold'] as num?)?.toInt() ?? 0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _currencyPill(Icons.diamond, CurrencyFormatter.format(gems),
                  AppTheme.neonBlue),
              const SizedBox(width: 8),
              _currencyPill(Icons.monetization_on,
                  CurrencyFormatter.format(gold), AppTheme.gold),
            ],
          );
        });
  }

  Widget _currencyPill(IconData icon, String val, Color color) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 5, top: 5, bottom: 5),
      decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(val,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
          const SizedBox(width: 6),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
                gradient: AppTheme.primaryGrad, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 10),
          )
        ],
      ),
    );
  }
}
