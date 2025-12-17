// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key); // <-- const constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tryb Ludo UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: AppShell(),
    );
  }
}
