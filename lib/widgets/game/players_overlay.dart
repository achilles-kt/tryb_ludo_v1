import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';
import '../../utils/image_utils.dart'; // Added

class PlayersOverlay extends StatelessWidget {
  final LudoGame game;
  const PlayersOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // final w = constraints.maxWidth;
        // final h = constraints.maxHeight;

        Widget playerSpot(PlayerSpot spot, PlayerMeta? meta) {
          if (meta == null) return const SizedBox.shrink();

          final child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spot == PlayerSpot.topRight || spot == PlayerSpot.bottomRight)
                _playerInfo(meta, true),
              _avatar(meta),
              if (spot == PlayerSpot.bottomLeft || spot == PlayerSpot.topLeft)
                _playerInfo(meta, false),
            ],
          );

          switch (spot) {
            case PlayerSpot.bottomLeft:
              return Positioned(
                left: 16,
                bottom: 16,
                child: child,
              );
            case PlayerSpot.topLeft:
              return Positioned(
                left: 16,
                top: 16,
                child: child,
              );
            case PlayerSpot.topRight:
              return Positioned(
                right: 16,
                top: 16,
                child: child,
              );
            case PlayerSpot.bottomRight:
              return Positioned(
                right: 16,
                bottom: 16,
                child: child,
              );
            default:
              return const SizedBox.shrink();
          }
        }

        // Get players from game
        // We need to map them to spots:
        // Seat 0 -> BottomLeft
        // Seat 1 -> TopRight
        // (For now assuming 2P)

        // We can iterate over known players in game._playerColors or similar
        // But PlayersOverlay needs access to player list.
        // LudoGame doesn't expose a nice list yet.
        // Let's assume we can get them via game.getPlayerMeta(spot) but we need to know WHICH spot has a player.

        // Better approach: Iterate over game.playerColors keys (uids) and map to spots.
        // But `playerColors` is private `_playerColors`.
        // Let's add a public getter for player spots in LudoGame or just hardcode the check here for now.

        // Actually, the previous code called `game.getPlayerMeta(spot)`.
        // Let's update `getPlayerMeta` in LudoGame to return null if no player at that spot.
        // And update this loop to only render if not null.

        // Wait, the user request said:
        // "In 2P, only show two avatar spots: bottom-left (seat 0), top-right (seat 1)."

        return Stack(
          children: [
            playerSpot(PlayerSpot.bottomLeft,
                game.getPlayerMeta(PlayerSpot.bottomLeft)),
            // playerSpot(PlayerSpot.topLeft, game.getPlayerMeta(PlayerSpot.topLeft)), // Hidden for 2P
            playerSpot(
                PlayerSpot.topRight, game.getPlayerMeta(PlayerSpot.topRight)),
            // playerSpot(PlayerSpot.bottomRight, game.getPlayerMeta(PlayerSpot.bottomRight)), // Hidden for 2P
          ],
        );
      },
    );
  }

  Widget _avatar(PlayerMeta meta) {
    // 1. Ring Color (Player Color)
    // 2. Turn Brightness (Active vs Inactive)
    final Color ringColor =
        meta.isTurn ? meta.playerColor : meta.playerColor.withOpacity(0.3);
    final double ringWidth = meta.isTurn ? 3.0 : 2.0;

    // 3. Team Glow (Background Shadow)
    final List<BoxShadow> shadows = [];
    if (meta.isTeam) {
      shadows.add(BoxShadow(
        color: (meta.glowColor ?? meta.playerColor).withOpacity(0.6),
        blurRadius: 20,
        spreadRadius: 4,
      ));
    }
    // Add extra glow for active turn
    if (meta.isTurn) {
      shadows.add(BoxShadow(
        color: meta.playerColor.withOpacity(0.4),
        blurRadius: 8,
        spreadRadius: 1,
      ));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ringColor,
          width: ringWidth,
        ),
        boxShadow: shadows,
        image: meta.avatarUrl != null
            ? DecorationImage(
                image: ImageUtils.getAvatarProvider(meta.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.grey.shade900,
      ),
      child: meta.avatarUrl == null
          ? const Icon(Icons.person, color: Colors.white54)
          : null,
    );
  }

  Widget _playerInfo(PlayerMeta meta, bool alignRight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            meta.isYou ? 'You' : meta.name ?? 'Player',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          // Team text removed as per visual requirements (Glow handles it)
        ],
      ),
    );
  }
}
