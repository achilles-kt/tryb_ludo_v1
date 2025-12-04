import 'package:flutter/material.dart';
import '../../game/ludo_game.dart';

class PlayersOverlay extends StatelessWidget {
  final LudoGame game;
  const PlayersOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // final w = constraints.maxWidth;
        // final h = constraints.maxHeight;

        Widget playerSpot(PlayerSpot spot) {
          if (spot == PlayerSpot.none) return const SizedBox.shrink();
          final data =
              game.getPlayerMeta(spot); // name, avatar, uid, isYou, isTeam

          final child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spot == PlayerSpot.topRight || spot == PlayerSpot.bottomRight)
                _playerInfo(data, true),
              _avatar(data),
              if (spot == PlayerSpot.bottomLeft || spot == PlayerSpot.topLeft)
                _playerInfo(data, false),
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

        return Stack(
          children: [
            playerSpot(PlayerSpot.bottomLeft),
            playerSpot(PlayerSpot.topLeft),
            playerSpot(PlayerSpot.topRight),
            playerSpot(PlayerSpot.bottomRight),
          ],
        );
      },
    );
  }

  Widget _avatar(PlayerMeta meta) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: meta.isTeam ? Colors.purpleAccent : Colors.grey.shade800,
          width: 2,
        ),
        boxShadow: meta.isTeam
            ? [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.5),
                  blurRadius: 12,
                )
              ]
            : [],
        image: meta.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(meta.avatarUrl!),
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
          if (meta.isTeam)
            Text(
              'Team',
              style: TextStyle(
                fontSize: 10,
                color: Colors.greenAccent.shade200,
              ),
            ),
        ],
      ),
    );
  }
}
