// lib/utils/modals.dart
import 'package:flutter/material.dart';
import '../widgets/modals/waiting_match_modal.dart';
import '../screens/game_screen.dart';

/// Show waiting modal and by default navigate to GameScreen when paired.
/// Returns the result map from the modal (tableId, gameId) or null.
Future<Map<String, dynamic>?> showWaitingMatchModal({
  required BuildContext context,
  required int entryFee,
  bool mockMode = false,
  Duration mockDelay = const Duration(seconds: 4),
  String mode = '2p',
}) async {
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WaitingMatchModal(
      entryFee: entryFee,
      mockMode: mockMode,
      mockDelay: mockDelay,
      mode: mode,
    ),
  );

  if (!context.mounted) return null;

  if (result is Map<String, dynamic>) {
    if (result['tableId'] != null && result['gameId'] != null) {
      // default nav; parent can avoid this by handling result or providing
      // a custom onPaired callback in WaitingMatchModal.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            GameScreen(gameId: result['gameId'], tableId: result['tableId']),
      ));
    }
    return result;
  }
  return null;
}
