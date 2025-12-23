import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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
        debugPrint(
            'Message also contained a notification: ${message.notification}');
        // Note: For visible notifications in foreground, we might need flutter_local_notifications
        // For now, we rely on the in-app UI (InviteOverlay) or just logs.
      }
    });
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
