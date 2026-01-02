import 'dart:io';
import 'package:flutter/material.dart';

class SocialLinkingSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;

  const SocialLinkingSection({
    super.key,
    required this.isLoading,
    required this.onGoogleTap,
    required this.onAppleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onGoogleTap,
            icon: const Icon(Icons.login, color: Colors.black),
            label: const Text("Continue with Google",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isLoading ? null : onAppleTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white24)),
            ),
            child: const Icon(Icons.apple, color: Colors.white, size: 28),
          ),
        ],
      ],
    );
  }
}
