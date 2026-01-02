import 'package:flutter/material.dart';
import '../common/glass_container.dart';

class ForfeitDialog extends StatelessWidget {
  final bool isTeamMode;
  final bool teammateLeft;

  const ForfeitDialog({
    super.key,
    this.isTeamMode = false,
    this.teammateLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    String message =
        "Are you sure you want to leave? You will lose this match and your stake.";

    if (isTeamMode) {
      if (teammateLeft) {
        message =
            "Your teammate has already left. If you leave, your team loses immediately.";
      } else {
        message =
            "If you leave, you will be removed from the game. Your teammate will have to play alone.";
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassContainer(
            borderRadius: 24,
            color: Colors.black.withOpacity(0.6),
            borderColor: Colors.white.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Forfeit Game?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Forfeit",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
