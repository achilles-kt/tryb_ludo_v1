import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../common/glass_container.dart';

class AgeGateOverlay extends StatelessWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onDenied;

  const AgeGateOverlay({
    super.key,
    required this.onConfirmed,
    required this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // No back
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Allow underlying UI to show through (blurred)
        body: Stack(
          children: [
            // 1. Full Screen Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),

            // 2. Center Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon or Illustration
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGrad,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonBlue.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        "Are you 13 or older?",
                        textAlign: TextAlign.center,
                        style: AppTheme.header.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 12),

                      // Subtext
                      Text(
                        "Tryb is only available for users aged 13 and above.",
                        textAlign: TextAlign.center,
                        style: AppTheme.text.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary CTA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onConfirmed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.neonBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            "I’m 13 or older",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secondary CTA
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: onDenied,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "I’m under 13",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
