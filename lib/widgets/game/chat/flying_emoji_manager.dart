import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/activity_item.dart';
import '../flying_bubble.dart';

class FlyingEmojiManager extends ChangeNotifier {
  final List<Map<String, dynamic>> _flyingEmojis = [];

  List<Map<String, dynamic>> get flyingEmojis => _flyingEmojis;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void trigger(ActivityItem msg, bool isMe, Offset startPos, Offset targetPos) {
    // Add small delay to stagger if multiple come in fast?
    // Or just fire immediately. Logic in Overlay had 200ms delay.
    // We'll mimic that.
    if (_isDisposed) return;

    Timer(const Duration(milliseconds: 200), () {
      if (_isDisposed) return;

      final flyId =
          'fly_${msg.timestamp}_${DateTime.now().microsecondsSinceEpoch}';

      final widget = FlyingBubble(
        key: ValueKey(flyId),
        text: msg.text,
        isMe: isMe,
        startPos: startPos,
        targetPos: targetPos,
        onComplete: () {
          if (!_isDisposed) _remove(flyId);
        },
      );

      _flyingEmojis.add({'id': flyId, 'widget': widget});
      notifyListeners();
    });
  }

  void _remove(String flyId) {
    if (_isDisposed) return;
    _flyingEmojis.removeWhere((e) => e['id'] == flyId);
    notifyListeners();
  }
}
