import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common/glass_container.dart';

class PayModal extends StatelessWidget {
  final String entryText;
  final VoidCallback onJoin;

  const PayModal({super.key, required this.entryText, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    // entryText might be "500 Gold" or raw number.
    // If we want consistency, we should pass int and format it here, but entryText is String.
    // Assuming caller formats it for now, BUT user asked for consistency.
    // I will check usages. Lobby passes "500 Gold" or "2.5k Gold".
    // I should strictly rely on the formatter if I can.
    // But refactoring the props is risky for this step.
    // However, I can ensure the *style* is consistent.
    // Let's stick to the visual consistency requested.

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3), width: 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.monetization_on,
                  size: 40, color: AppTheme.gold),
            ),
            const SizedBox(height: 16),
            Text('PAY ENTRY FEE',
                style: AppTheme.header.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              entryText,
              style: AppTheme.text.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onJoin,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGrad,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    'PAY & JOIN',
                    style: AppTheme.text.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: AppTheme.label.copyWith(color: Colors.white54)),
            )
          ],
        ),
      ),
    );
  }
}
