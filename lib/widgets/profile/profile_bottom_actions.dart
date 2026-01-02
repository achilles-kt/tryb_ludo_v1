import 'package:flutter/material.dart';
import 'edit/social_linking_section.dart';
import '../../services/conversion_service.dart'; // Import

class ProfileBottomActions extends StatelessWidget {
  final bool isAnon;
  final bool isLoading;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;
  final VoidCallback onSaveTap;
  final VoidCallback onLogout;
  final NudgeType nudgeType; // New

  const ProfileBottomActions({
    super.key,
    required this.isAnon,
    required this.isLoading,
    required this.onGoogleTap,
    required this.onAppleTap,
    required this.onSaveTap,
    required this.onLogout,
    this.nudgeType = NudgeType.none,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F1218);
    const primary = Color(0xFF3B82F6);

    // Highlight logic
    final isNudge = nudgeType != NudgeType.none;
    final highlightColor = nudgeType == NudgeType.hard
        ? Colors.amberAccent
        : Colors.lightBlueAccent;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          // Subtle styling change if nudge
          border: isNudge
              ? Border(
                  top: BorderSide(
                      color: highlightColor.withOpacity(0.2), width: 1))
              : null),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAnon) ...[
            // If Nudge, maybe add a small text "Secure Account:" above icons?
            // Or just wrap in a highlight container?
            Container(
              padding: isNudge ? const EdgeInsets.all(8) : EdgeInsets.zero,
              decoration: isNudge
                  ? BoxDecoration(
                      border:
                          Border.all(color: highlightColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                      color: highlightColor.withOpacity(0.05))
                  : null,
              child: SocialLinkingSection(
                isLoading: isLoading,
                onGoogleTap: onGoogleTap,
                onAppleTap: onAppleTap,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isLoading ? null : onSaveTap,
                child: const Text("Save locally & Continue",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSaveTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Save & Continue →",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          // LOGOUT BUTTON
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 16, color: Colors.white30),
              label: const Text("Logout",
                  style: TextStyle(color: Colors.white30, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}
