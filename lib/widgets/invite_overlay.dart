import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../services/invite_service.dart';
import '../screens/game_screen.dart';

/// Global Overlay to listen for invites continuously.
class InviteOverlay extends StatefulWidget {
  final Widget child;
  const InviteOverlay({super.key, required this.child});

  @override
  _InviteOverlayState createState() => _InviteOverlayState();
}

class _InviteOverlayState extends State<InviteOverlay> {
  final InviteService _inviteService = InviteService();
  StreamSubscription? _inviteSub;
  String? _myUid;

  // Track if we are already showing a dialog to avoid stacking
  bool _isDialogShowing = false;
  String? _currentDialogInviteId;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    if (_myUid != null) {
      _startListening();
      _initFCM();
    }

    // Listen for auth changes to restart listener
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != _myUid) {
        _inviteSub?.cancel();
        _myUid = user?.uid;
        if (_myUid != null) {
          _startListening();
          _initFCM();
        }
      }
    });
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1. Request Permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Get Token
      try {
        final token = await messaging.getToken();
        if (token != null) {
          await FirebaseDatabase.instance.ref('users/$uid/fcmToken').set(token);
          debugPrint("FCM Token saved for $uid: $token");
        }
      } catch (e) {
        debugPrint("Error getting FCM token: $e");
      }
    }

    // 3. Foreground Listener (Optional, for debugging or in-app toasts)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "FCM Message Received in Foreground: ${message.notification?.title}");
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "${message.notification!.title}: ${message.notification!.body}"),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 3),
        ));
      }
    });
  }

  void _startListening() {
    _inviteSub = _inviteService.watchIncomingInvites(_myUid!).listen((event) {
      final raw = event.snapshot.value as Map?;

      // 1. Check if the currently shown invite is still valid
      if (_isDialogShowing && _currentDialogInviteId != null) {
        final currentInvite = raw?[_currentDialogInviteId];
        // If invite is deleted or no longer pending (e.g., cancelled), close dialog.
        if (currentInvite == null || currentInvite['status'] != 'pending') {
          // We use a safe pop here. Note: This assumes the dialog is top-most.
          // In complex flows this might pop the wrong thing, but for this overlay it's likely safe.
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Invite was cancelled by the sender.")),
            );
          }
          _isDialogShowing = false;
          _currentDialogInviteId = null;
        }
      }

      if (raw == null) return;

      // 2. Find a new pending invite if we aren't showing one
      String? pendingInviteId;
      Map? pendingInviteData;

      raw.forEach((key, value) {
        if (value['status'] == 'pending') {
          pendingInviteId = key;
          pendingInviteData = value;
        }
      });

      if (pendingInviteId != null && !_isDialogShowing) {
        _currentDialogInviteId = pendingInviteId;
        _showInviteDialog(pendingInviteId!, pendingInviteData!);
      }
    });
  }

  void _showInviteDialog(String inviteId, Map data) async {
    _isDialogShowing = true;

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2025),
              title: const Text("Game Invite!",
                  style: TextStyle(color: Colors.white)),
              content: const Text(
                  "A friend wants to play Ludo with you. Accept?",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () async {
                      // REJECT
                      try {
                        await _inviteService.respondToInvite(
                            inviteId, "reject");
                      } catch (e) {
                        debugPrint("Reject error: $e");
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text("No",
                        style: TextStyle(color: Colors.redAccent))),
                TextButton(
                    onPressed: () async {
                      // ACCEPT
                      try {
                        if (ctx.mounted) {
                          Navigator.pop(ctx); // Close dialog first
                        }

                        final result = await _inviteService.respondToInvite(
                            inviteId, "accept");

                        final gameId = result['gameId'];
                        final tableId = result['tableId'];

                        if (gameId != null && tableId != null && mounted) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => GameScreen(
                                  gameId: gameId, tableId: tableId)));
                        }
                      } catch (e) {
                        debugPrint("Accept error: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to join: $e")));
                        }
                      }
                    },
                    child: const Text("Yes, Play")),
              ],
            ));

    _isDialogShowing = false;
    _currentDialogInviteId = null;
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
