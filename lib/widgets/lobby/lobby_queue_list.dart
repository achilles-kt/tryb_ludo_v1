import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../table_card.dart';
import '../../services/config_service.dart';

class LobbyQueueList extends StatelessWidget {
  final AsyncSnapshot<DatabaseEvent> queueSnap;
  final String? currentUid;
  final Function(String pushId, int entryFee, int gemFee, String hostUid)
      onJoin;

  const LobbyQueueList({
    super.key,
    required this.queueSnap,
    required this.currentUid,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    // If no data or waiting, return empty
    if (!queueSnap.hasData || queueSnap.data?.snapshot.value == null) {
      debugPrint("LobbyQueueList: No Data or Null");
      return const SizedBox();
    }

    final queueData = queueSnap.data!.snapshot.value as Map;
    debugPrint("LobbyQueueList: Data Keys: ${queueData.keys}");
    final List<Widget> listItems = [];

    // Iterate through map
    queueData.forEach((key, value) {
      if (value is! Map) return;
      final val = value;
      final uid = val['uid'];

      if (uid == currentUid) return; // Don't show self in queue

      final avatar = val['avatar'] as String?;
      final name = val['name'] as String?;

      listItems.add(
        TableCard(
          mode: '2P',
          winText: 'WIN ${ConfigService.instance.gameStake * 2} GOLD',
          entryFee: ConfigService.instance.gameStake,
          isActive: false,
          isTeam: false,
          playerAvatars: [if (avatar != null) avatar],
          playerNames: [if (name != null) name],
          onTap: () => onJoin(key, ConfigService.instance.gameStake,
              ConfigService.instance.gemFee, uid),
        ),
      );
      listItems.add(const SizedBox(height: 15));
    });

    return Column(children: listItems);
  }
}
