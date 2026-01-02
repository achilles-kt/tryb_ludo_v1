import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/activity_item.dart';

class ChatBubbleManager extends ChangeNotifier {
  final Map<String, ActivityItem> _activeBubbles = {};
  final Map<String, Timer> _bubbleTimers = {};

  Map<String, ActivityItem> get activeBubbles => _activeBubbles;

  void addMessage(ActivityItem msg) {
    // Update active bubble (Latest wins)
    _activeBubbles[msg.senderId] = msg;
    notifyListeners();

    // Reset Timer
    _bubbleTimers[msg.senderId]?.cancel();
    _bubbleTimers[msg.senderId] = Timer(const Duration(seconds: 8), () {
      // Only remove if it's still THIS message
      if (_activeBubbles[msg.senderId]?.id == msg.id) {
        _activeBubbles.remove(msg.senderId);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    for (var t in _bubbleTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
