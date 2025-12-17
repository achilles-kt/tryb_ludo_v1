import 'package:flutter/material.dart';
import '../constants.dart';

class TableCard extends StatelessWidget {
  final String mode;
  final String winText;
  final int? entryFee;
  final String? entryLabel; // Fallback for "2.5k Gold" or "Full"
  final VoidCallback? onTap;

  const TableCard({
    Key? key,
    required this.mode,
    required this.winText,
    this.entryFee,
    this.entryLabel,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine display string
    String displayEntry;
    if (entryFee != null) {
      displayEntry = '$entryFee Gold';
    } else {
      displayEntry = entryLabel ?? '';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder)),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 0.6)),
                  child: Text(mode,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700))),
              Text(winText,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: const [
                CircleAvatar(
                    backgroundImage: AssetImage('assets/avatars/a4.png'),
                    radius: 21),
                SizedBox(width: 8),
                Text('VS',
                    style: TextStyle(
                        color: Colors.white30, fontWeight: FontWeight.w800))
              ]),
              Text(displayEntry,
                  style: TextStyle(
                      color: displayEntry == 'Full'
                          ? AppColors.textMuted
                          : AppColors.neonGreen,
                      fontWeight: FontWeight.w700))
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Crucial Fix: Only add "Entry:" prefix here using our clean values
              Text('Entry: $displayEntry',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const Text('Open',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted))
            ])
          ],
        ),
      ),
    );
  }
}
