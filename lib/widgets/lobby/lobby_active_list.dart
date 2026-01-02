import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../table_card.dart';
import '../../services/config_service.dart';

class LobbyActiveList extends StatelessWidget {
  final AsyncSnapshot<DatabaseEvent> tablesSnap;
  final String? currentUid;
  final Function(int fee, String mode) onJoinQueue;
  final VoidCallback onSpectate;

  const LobbyActiveList({
    super.key,
    required this.tablesSnap,
    required this.currentUid,
    required this.onJoinQueue,
    required this.onSpectate,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> realGames = _buildRealActiveGames();
    bool hasRealGames = realGames.isNotEmpty;

    List<Widget> content = [];

    // 1. If No Real Games -> Show Quick Join Cards
    if (!hasRealGames) {
      content.addAll(_buildEmptyStateWaitingCards());
    } else {
      content.addAll(realGames);
    }

    // 2. Always show High Stakes / Dummy Tables at the bottom
    content.addAll(_buildHighStakesFeatured());

    return Column(children: content);
  }

  /// Builds the list of currently active real games from Firebase
  List<Widget> _buildRealActiveGames() {
    List<Widget> items = [];
    if (tablesSnap.hasData && tablesSnap.data?.snapshot.value != null) {
      final tablesData = tablesSnap.data!.snapshot.value as Map;

      tablesData.forEach((key, value) {
        if (value is! Map) return;
        final val = value;
        final players = val['players'] as Map?;

        if (players != null && currentUid != null) {
          if (players.containsKey(currentUid)) return; // Hide my own games
        }

        final stake = val['stake'] ?? ConfigService.instance.gameStake;
        final isTeam = val['mode'] == '4p' || val['mode'] == 'team';

        List<String> playerAvatars = [];
        List<String> playerNames = [];

        if (players != null) {
          var playerEntries = players.entries.toList();
          playerEntries.sort((a, b) {
            final sA = (a.value as Map)['seat'] ?? 0;
            final sB = (b.value as Map)['seat'] ?? 0;
            return sA.compareTo(sB);
          });

          for (var entry in playerEntries) {
            final pData = entry.value as Map;
            playerAvatars.add(pData['photoURL'] ?? pData['avatar'] ?? '');
            playerNames.add(pData['displayName'] ?? pData['name'] ?? 'Player');
          }
        }

        items.add(TableCard(
            mode: isTeam ? 'TEAM' : '2P',
            winText: 'WIN ${stake * 2} GOLD',
            entryFee: stake as int?,
            isActive: true, // It's a real active game
            isTeam: isTeam,
            playerAvatars: playerAvatars,
            playerNames: playerNames,
            onTap: onSpectate));
        items.add(const SizedBox(height: 15));
      });
    }
    return items;
  }

  /// Builds the "Simulation" waiting cards for Quick Join (Empty State)
  List<Widget> _buildEmptyStateWaitingCards() {
    return [
      // 2P Waiting Card
      TableCard(
        mode: '2P',
        winText: 'WIN 1000 GOLD',
        entryFee: 500,
        entryLabel: '500 Gold',
        isActive: false, // Open
        isTeam: false,
        playerAvatars: ['assets/avatars/a7.png'], // Simulate 1 waiter
        playerNames: ['Waiting...'],
        onTap: () => onJoinQueue(500, '2p'),
      ),
      const SizedBox(height: 15),

      // Team Up Waiting Card
      TableCard(
        mode: 'TEAM',
        winText: 'WIN 5000 GOLD',
        entryFee: 2500,
        entryLabel: '2.5k Gold',
        isActive: false, // Open
        isTeam: true,
        playerAvatars: ['assets/avatars/a2.png'], // Simulate 1 waiter
        playerNames: ['Waiting...'],
        onTap: () => onJoinQueue(2500, '4p'),
      ),
      const SizedBox(height: 15),
    ];
  }

  /// Builds the dummy high-stakes tables
  List<Widget> _buildHighStakesFeatured() {
    return [
      TableCard(
        mode: 'TEAMS',
        winText: 'WIN 100K GOLD',
        entryFee: 50000,
        isActive: true,
        isTeam: true,
        playerAvatars: [
          'assets/avatars/a1.png',
          'assets/avatars/a4.png',
          'assets/avatars/a2.png',
          'assets/avatars/a5.png',
        ],
        playerNames: ['King', 'Queen', 'Ace', 'Jack'],
        onTap: () {}, // No-op
      ),
      const SizedBox(height: 15),
      TableCard(
        mode: '2P',
        winText: 'WIN 50K GOLD',
        entryFee: 25000,
        isActive: true,
        isTeam: false,
        playerAvatars: [
          'assets/avatars/a3.png',
          'assets/avatars/a6.png',
        ],
        playerNames: ['Pro', 'Master'],
        onTap: () {},
      ),
      const SizedBox(height: 15),
    ];
  }
}
