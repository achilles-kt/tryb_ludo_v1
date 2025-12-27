import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tryb_ludo_v1/firebase_options.dart';
import 'package:tryb_ludo_v1/screens/main_screen.dart';
import 'package:tryb_ludo_v1/services/config_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _initApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    final startTime = DateTime.now();

    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Initialize Config
      await ConfigService.instance.init();

      // 3. Auth Check / Sign In
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;

      if (user == null) {
        debugPrint('SPLASH: Signing in anonymously...');
        final cred = await auth.signInAnonymously();
        user = cred.user;
      }

      if (user != null) {
        debugPrint('SPLASH: User authenticated: ${user.uid}');

        // Check Profile
        final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          debugPrint('SPLASH: Profile missing. Bootstrapping...');
          try {
            await FirebaseFunctions.instance
                .httpsCallable('bootstrapUser')
                .call();
            debugPrint('SPLASH: Bootstrap complete.');
          } catch (e) {
            debugPrint('SPLASH: Bootstrap failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('SPLASH ERROR: $e');
      // Handle error visually? For now just proceed or stuck.
    }

    // Ensure splash is visible for at least 2 seconds for branding
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inSeconds < 2) {
      await Future.delayed(
          Duration(milliseconds: 2000 - elapsed.inMilliseconds));
    }

    // Check for Deferred Deep Link (Fingerprint)
    String? deferredLink;
    debugPrint('SPLASH: Checking deferred links...');
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('checkDeferredLink')
          .call()
          .timeout(const Duration(seconds: 3));

      final data = result.data as Map?;
      final code = data?['code'];
      if (code != null) {
        deferredLink = "tryb://join/$code";
        debugPrint("SPLASH: Found Deferred Link (Fingerprint): $deferredLink");
      } else {
        debugPrint("SPLASH: No deferred link found.");
      }
    } catch (e) {
      debugPrint("SPLASH: Deferred check failed/timed out: $e");
      // Continue execution
    }

    /*
    // Check Clipboard (Backup)
    debugPrint('SPLASH: Checking clipboard...');
    if (deferredLink == null) {
      try {
        final cdata = await Clipboard.getData(Clipboard.kTextPlain)
            .timeout(const Duration(seconds: 1));
        if (cdata?.text != null) {
          final txt = cdata!.text!.trim();
          if (txt.startsWith('tryb://')) {
            deferredLink = txt;
            debugPrint("SPLASH: Found Deferred Link (Clipboard): $deferredLink");
          }
        }
      } catch (e) {
        // clipboard error (e.g. privacy restriction)
        debugPrint("SPLASH: Clipboard check failed: $e");
      }
    }
    */

    debugPrint('SPLASH: Init complete. Navigating...');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => MainScreen(initialDeepLink: deferredLink)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF1E1E1E), // Dark background matching theme
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/imgs/logo.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),
              // Optional: App Name text if logo doesn't have it
              // const Text(
              //   'Tryb',
              //   style: TextStyle(
              //     color: Colors.white,
              //     fontSize: 32,
              //     fontWeight: FontWeight.bold,
              //     letterSpacing: 2,
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
