// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service (FCM)
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key); // <-- const constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tryb Ludo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: AppShell(),
    );
  }
}
