import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'widgets/notification_overlay.dart'; // Added here

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service (FCM)
  // Initialize Notification Service (FCM) - Don't await to avoid blocking UI
  NotificationService.initialize();
  PresenceService().initialize(); // Presence Tracking

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

// ...

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tryb Ludo',
      navigatorKey: navigatorKey, // Use the key from notification_overlay.dart
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AppShell(),
      builder: (context, child) {
        return InAppNotificationOverlay(child: child ?? const SizedBox());
      },
    );
  }
}
