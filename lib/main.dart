// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart'; // <- required

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('FIREBASE INIT: OK');
  } catch (e, st) {
    debugPrint('FIREBASE INIT FAILED: $e');
    debugPrint(st.toString());
  }

  // 2) Anonymous Sign-in check
  try {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      debugPrint('FIREBASE AUTH: signed in anonymously; uid=${cred.user?.uid}');
    } else {
      debugPrint('FIREBASE AUTH: already signed in; uid=${user.uid}');
    }
  } catch (e, st) {
    debugPrint('FIREBASE AUTH ERROR: $e');
    debugPrint(st.toString());
  }

  // 3) Small test DB write (debug/test path) — Step 3 verification helper
  try {
    final dbRef = FirebaseDatabase.instance.ref('debug/testFromApp');
    await dbRef.set({
      'uid': FirebaseAuth.instance.currentUser?.uid ?? 'null',
      'ts': ServerValue.timestamp,
      'note': 'hello-from-app'
    });
    debugPrint('DB WRITE: wrote debug/testFromApp');
  } catch (e, st) {
    debugPrint('DB WRITE ERROR: $e');
    debugPrint(st.toString());
  }

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
