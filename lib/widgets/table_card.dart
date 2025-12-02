import 'package:flutter/material.dart';
import '../constants.dart';

class TableCard extends StatelessWidget {
  final String mode;
  final String winText;
  final String entry;
  final VoidCallback? onTap;

  const TableCard(
      {required this.mode,
      required this.winText,
      required this.entry,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder)),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 0.6)),
                  child: Text(mode,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700))),
              Text(winText,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
            ]),
            SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                CircleAvatar(
                    backgroundImage: AssetImage('assets/avatars/a4.png'),
                    radius: 21),
                SizedBox(width: 8),
                Text('VS',
                    style: TextStyle(
                        color: Colors.white30, fontWeight: FontWeight.w800))
              ]),
              entry == 'Full'
                  ? Text('Full', style: TextStyle(color: AppColors.textMuted))
                  : Text(entry,
                      style: TextStyle(
                          color: AppColors.neonGreen,
                          fontWeight: FontWeight.w700))
            ]),
            SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Entry: $entry',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('Open',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted))
            ])
          ],
        ),
      ),
    );
  }
}
