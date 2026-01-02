import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/play_sheet.dart';
import '../../widgets/private_table_sheet.dart';
import '../../controllers/lobby_controller.dart';

// This widget encapsulates the "Play" button logic flows
class MatchmakingSheet {
  static void show(BuildContext context, LobbyController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14161b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => PlayOptionsSheet(onSelect: (mode) async {
        Navigator.of(context).pop();

        if (mode == 'create_2p') {
          // Private Table Flow
          showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF14161b),
              builder: (ctx) => PrivateTableSheet(onPublish: () {
                    Navigator.pop(ctx);
                    controller.handlePublishTable();
                  }, onInvite: () async {
                    Navigator.pop(ctx);
                    try {
                      final link = await controller.inviteFriendLink();
                      await Share.share(
                          'Join me on Tryb Ludo! Play here: $link');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to share: $e")));
                      }
                    }
                  }));
        } else if (mode == '2p') {
          controller.joinQueueFlow(fee: 500, matchMode: '2p');
        } else if (mode == 'team') {
          controller.joinQueueFlow(fee: 2500, matchMode: '4p');
        }
      }),
    );
  }
}
