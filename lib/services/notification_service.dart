import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/notification_overlay.dart'; // For navigatorKey
import '../screens/conversation_screen.dart';
import '../screens/game_screen.dart';

/// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Stream for In-App Overlay
  static final StreamController<RemoteMessage> _controller =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get onNotificationReceived => _controller.stream;

  static Future<void> initialize() async {
    // 1. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 3. Update Token if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await updateToken(user.uid);
    }

    // 4. Listen to token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      if (FirebaseAuth.instance.currentUser != null) {
        updateToken(FirebaseAuth.instance.currentUser!.uid);
      }
    });

    // 5. Foreground Message Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        // Feed to Overlay
        _controller.add(message);
      }
    });

    // 6. Handle App Open from Background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 7. Handle App Launch from Terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message);
      }
    });
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    debugPrint("Handling interaction: ${message.data}");
    final data = message.data;
    final type = data['type'];

    // 1. Game Deep Link
    // If notification has gameId, check if it's active
    final gameId = data['gameId'];
    if (gameId != null && gameId.toString().isNotEmpty) {
      try {
        final ref = FirebaseDatabase.instance.ref('games/$gameId');
        final snap = await ref.get();
        if (snap.exists) {
          final gData = snap.value as Map;
          final state = gData['state'];
          final tableId = gData['tableId'] ?? 'unknown';

          if (state == 'active') {
            debugPrint(
                "🔔 Deep Linking to Active Game: $gameId (Table: $tableId)");
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => GameScreen(gameId: gameId, tableId: tableId),
              ),
            );
            return; // Stop here, don't go to chat screen
          } else {
            debugPrint(
                "🔔 Game $gameId is not active (State: $state). Redirecting to Chat.");
          }
        }
      } catch (e) {
        debugPrint("Error checking game state for deep link: $e");
      }
    }

    // 2. Contact Joined
    if (type == 'contact_joined') {
      final peerId = data['peerId'];
      if (peerId != null) {
        debugPrint("🔔 Contact Joined: $peerId. Opening Conversation.");
        // We could open ProfileScreen(peerId) or ConversationScreen.
        // Conversation is more engaging "Say Hi".
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              peerId: peerId,
              peerName:
                  'New Friend', // We might not have name here yet, ConversationScreen usually fetches it or we pass it?
              // Better to pass what we have or let screen fetch.
              // Notification payload might not have name.
              peerAvatar: '',
            ),
          ),
        );
        return;
      }
    }

    // 3. Chat / Social Fallback
    if (type == 'chat' ||
        type == 'game_invite' ||
        type == 'game_chat' ||
        type == 'friend_request') {
      final senderId = data['senderId'] ?? data['peerId']; // unifying
      final senderName = data['senderName'];

      if (senderId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              peerId: senderId,
              peerName: senderName ?? 'Chat',
              peerAvatar: data['senderAvatar'] ?? '',
            ),
          ),
        );
      }
    }
  }

  static Future<void> updateToken(String uid) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Attempt to get APNS token with a small retry
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint("APNS token not ready, waiting...");
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint(
                "Warning: APNS token still null. Skipping FCM token fetch to avoid crash.");
            return;
          }
        }
      }

      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        await FirebaseDatabase.instance.ref('users/$uid/fcmToken').set(token);
      }
    } catch (e) {
      debugPrint("Error fetching/saving FCM token: $e");
    }
  }
}
