import 'package:flutter/material.dart';

import '../constants.dart';

class PrivateTableSheet extends StatefulWidget {
  final VoidCallback onPublish;
  final VoidCallback onInvite;

  const PrivateTableSheet({
    Key? key,
    required this.onPublish,
    required this.onInvite,
  }) : super(key: key);

  @override
  State<PrivateTableSheet> createState() => _PrivateTableSheetState();
}

class _PrivateTableSheetState extends State<PrivateTableSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: Colors.white)),
              SizedBox(width: 8),
              Text('Two Player Table',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 18),
          _actionRow(
            icon: Icons.share,
            title: 'Invite New Friend',
            desc: 'Share a link to play 1v1',
            color: AppColors.neonGreen,
            onTap: widget.onInvite,
          ),
          SizedBox(height: 16),
          _actionRow(
            icon: Icons.public,
            title: 'Publish my Table',
            desc: 'Join the public queue',
            color: AppColors.neonBlue,
            onTap: widget.onPublish,
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: color),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
