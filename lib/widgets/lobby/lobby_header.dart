import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';

class LobbyHeader extends StatelessWidget {
  const LobbyHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          const Text("Tryb",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),

          // Real Online Count Logic
          StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('status').onValue,
              builder: (context, snapshot) {
                int realOnline = 0;
                final data = snapshot.data?.snapshot.value as Map?;
                if (data != null) {
                  data.forEach((k, v) {
                    if (v is Map && v['state'] == 'online') {
                      realOnline++;
                    }
                  });
                }
                // Add 256 as requested
                final displayCount = realOnline + 256;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xffffffff).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle,
                          color: AppTheme.neonGreen, size: 8),
                      const SizedBox(width: 6),
                      Text("$displayCount Online",
                          style: const TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))
                    ],
                  ),
                );
              })
        ],
      ),
    );
  }
}
