import 'package:flutter/material.dart';
import '../constants.dart';
import 'create_table_sheet.dart';

class PlayOptionsSheet extends StatelessWidget {
  final Function(String mode) onSelect;
  const PlayOptionsSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Play & Win',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _optCard(
                  icon: Icons.person,
                  title: 'Join 2P',
                  sub: 'Quick 1v1',
                  onTap: () => onSelect('2p'))),
          SizedBox(width: 12),
          Expanded(
              child: _optCard(
                  icon: Icons.group,
                  title: 'Join Team',
                  sub: 'Squad 2v2',
                  onTap: () => onSelect('team'))),
        ]),
        SizedBox(height: 12),
        Text('OR', style: TextStyle(color: Colors.grey[500])),
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            // create table flow
            showModalBottomSheet(
              context: context,
              backgroundColor: Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => CreateTableOptionsSheet(onSelect: (mode) {
                // Navigate deeper based on selection
                Navigator.pop(ctx);
                onSelect(mode); // Delegate back to parent or handle here?
                // Actually, parent 'onSelect' in Lobby typically handles '2p' or 'team'.
                // But for 'Create' flow, we might need a specific signal or
                // handle the next sheet here.
                // Let's rely on callback for now, but LobbyScreen needs to know if it's "Create 2P" vs "Join 2P"
                // The current onSelect takes just a string.
                // We'll pass "create_2p" or similar?
              }),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.symmetric(vertical: 14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle, color: AppColors.neonPurple),
            SizedBox(width: 10),
            Text('Create my Table',
                style: TextStyle(fontWeight: FontWeight.w600))
          ]),
        )
      ]),
    );
  }

  Widget _optCard(
      {required IconData icon,
      required String title,
      required String sub,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10)),
        child: Column(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blueAccent)),
              child: Icon(icon, color: AppColors.neonBlue)),
          SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.grey[400], fontSize: 11))
        ]),
      ),
    );
  }
}
