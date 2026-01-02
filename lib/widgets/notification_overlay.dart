import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme/app_theme.dart';
import 'common/glass_container.dart';
import '../services/notification_service.dart';

import '../services/presence_service.dart';

class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;

  RemoteMessage? _currentMsg;
  Timer? _hideTimer;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _sub = NotificationService.onNotificationReceived.listen((msg) {
      _showNotification(msg);
    });
  }

  void _showNotification(RemoteMessage msg) {
    // Check if we are currently playing the game this message belongs to
    final currentGameId = PresenceService().currentPlayingGameId;
    if (currentGameId != null) {
      // Robustly parse gameId from data
      String? msgGameId = msg.data['gameId'];

      // If not in root data, check payload (which might be a JSON string)
      if (msgGameId == null && msg.data['payload'] != null) {
        try {
          final payloadRaw = msg.data['payload'];
          if (payloadRaw is String) {
            final Map<String, dynamic> payload = jsonDecode(payloadRaw);
            msgGameId = payload['gameId'];
          } else if (payloadRaw is Map) {
            // In case it's already a map (unlikely for FCM data)
            msgGameId = payloadRaw['gameId'];
          }
        } catch (e) {
          debugPrint("Note: Failed to parse notification payload JSON: $e");
        }
      }

      final type = msg.data['type'];

      // If notification is about the current game (chat or game_result), suppress it.
      if (msgGameId != null && msgGameId == currentGameId) {
        if (type == 'chat' || type == 'game_chat' || type == 'game_result') {
          debugPrint(
              "🔕 Suppressing In-App Notification (User is in game: $currentGameId)");
          return;
        }
      }
    }

    // If showing one, hide it first then show new? Or just replace?
    // Let's replace.
    setState(() {
      _currentMsg = msg;
    });

    _controller.forward();

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse();
  }

  void _onTap() {
    _dismiss();
    if (_currentMsg == null) return;

    final type = _currentMsg!.data['type'];
    final context =
        navigatorKey.currentContext; // Needs global key or passed context?
    // Wait, Overlay wraps MaterialApp, so we don't have a Navigator context *inside* it easily unless we use a GlobalKey<NavigatorState>.
    // Usually NotificationService should have a navigator key reference, or we pass it down.

    // For now, let's assume MainScreen handles navigation or we use a GlobalKey.
    // Let's print for now, implementation depends on Nav setup.
    // Ideally: NavigationService.navigateTo(type, args)

    debugPrint("Tapped Notification: $type");

    // Simple basic check if we can access Navigator
    if (context != null) {
      // Logic to push route based on type
      // This part typically requires a NavigationService or GlobalKey
      // I will assume for now we just log it, or if I can access the navigatorKey from main.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Heads Up Banner
        AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnim,
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: _onTap,
                        onVerticalDragEnd: (details) {
                          // Swipe up to dismiss
                          if (details.primaryVelocity! < 0) {
                            _dismiss();
                          }
                        },
                        child: _buildBannerContent(),
                      ),
                    ),
                  ),
                ),
              );
            }),
      ],
    );
  }

  Widget _buildBannerContent() {
    if (_currentMsg == null) return const SizedBox.shrink();

    final title = _currentMsg!.notification?.title ?? 'Notification';
    final body = _currentMsg!.notification?.body ?? '';
    final type = _currentMsg!.data['type'];

    IconData icon = Icons.notifications;
    Color color = AppTheme.neonBlue;

    if (type == 'chat') {
      icon = Icons.chat_bubble;
      color = AppTheme.neonGreen;
    } else if (type == 'friend_request') {
      icon = Icons.person_add;
      color = AppTheme.gold;
    } else if (type == 'private_invite') {
      icon = Icons.gamepad;
      color = AppTheme.neonRed;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: AppTheme.bgDark.withOpacity(0.9), // Darker for readability
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.text
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                if (body.isNotEmpty)
                  Text(body,
                      style: AppTheme.label.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (type == 'private_invite')
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppTheme.neonBlue,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text("JOIN",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            )
        ],
      ),
    );
  }
}

// Global Key to allow access to Navigator from Overlay if placed above MaterialApp
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
