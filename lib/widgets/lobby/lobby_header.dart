import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../theme/app_theme.dart';

class LobbyHeader extends StatefulWidget {
  const LobbyHeader({super.key});

  @override
  State<LobbyHeader> createState() => _LobbyHeaderState();
}

class _LobbyHeaderState extends State<LobbyHeader> {
  late Stream<DatabaseEvent> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseDatabase.instance.ref('status').onValue;
  }

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
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Online Count Error: ${snapshot.error}");
                  return Text("Err: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red, fontSize: 8));
                }

                int realOnline = 0;
                final rawValue = snapshot.data?.snapshot.value;

                if (rawValue != null) {
                  debugPrint("LobbyHeader: Raw Online Data: $rawValue");
                  if (rawValue is Map) {
                    rawValue.forEach((k, v) {
                      // debugPrint("User $k: $v");
                      if (v is Map) {
                        final state = v['state'];
                        // debugPrint("  State: $state");
                        if (state == 'online') {
                          realOnline++;
                        }
                      }
                    });
                  } else if (rawValue is List) {
                    for (var v in rawValue) {
                      if (v is Map && v['state'] == 'online') {
                        realOnline++;
                      }
                    }
                  }
                }
                debugPrint("LobbyHeader: Real Online Count: $realOnline");

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
