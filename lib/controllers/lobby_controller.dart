import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:app_links/app_links.dart';
import '../services/invite_service.dart';
import '../services/contact_service.dart';
import '../services/presence_service.dart';
import '../services/conversion_service.dart';
import '../widgets/modals/pay_modal.dart';
import '../utils/modals.dart'; // showWaitingMatchModal

class LobbyController extends ChangeNotifier {
  final InviteService _inviteService = InviteService();
  final AppLinks _appLinks = AppLinks();
  late BuildContext
      _context; // Hacky but needed for modal? Better passed in init.
  // Actually, init(context) is better.
  // Wait, LobbyScreen calls init(link).
  // We can pass context to checkSessionStart later or store it.
  // Storing BuildContext in Controller is bad practice but common for navigation services.
  // Let's rely on LobbyScreen to call checkSessionStart itself? NO, controller drives logic.
  // Let's add a context scheduler/holder or just accept we need to pass it?

  // Alternative: Controller exposes a stream "showNudge" and View listens.
  // That's cleaner but more work.
  // Let's stick to direct call but maybe pass context to init?
  // User code structure: init(initialDeepLink).
  // Let's add setContext somewhere or just pass it to init.

  // Re-reading LobbyScreen.dart:
  // _controller.init(widget.initialDeepLink); in initState.
  // We can change init signature.

  // Re-reading user request: "LobbyController.init() -> ConversionService.instance.checkSessionStart()".
  // ConversionService needs context to show modal.

  // Let's modify init to accept context.

  // Constructor
  LobbyController() {
    // Trigger silent sync in background
    ContactService.instance.trySilentSync();
  }

  User? _currentUser;
  bool _authReady = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<Uri>? _linkSub;

  // Getters
  User? get currentUser => _currentUser;
  bool get authReady => _authReady;

  // Events (using callbacks to keep it simple without full Stream access)
  Function(String gameId, String tableId)? onRejoinGame;
  Function(Uri uri)? onDeepLink;

  void init(BuildContext context, String? initialDeepLink) {
    // Changed signature
    _context = context;
    _initAuth(initialDeepLink);
    _initDeepLinks();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  void _initAuth(String? initialLink) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      _authReady = true;
      notifyListeners();

      if (user != null) {
        // Force Online State
        PresenceService().setOnline();

        _checkRejoin();
        _checkAgeStatus(); // Check Age Gate

        // Trigger Conversion Check
        // Use a post-frame callback to ensure safe context usage
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_context.mounted) {
            ConversionService.instance.checkSessionStart(_context);
          }
        });

        // Handle initial link if present and not handled
        if (initialLink != null) {
          try {
            final uri = Uri.parse(initialLink);
            // Verify link again before passing
            if (uri.scheme == 'tryb' && uri.host == 'join') {
              handleDeepLink(uri);
            }
          } catch (e) {
            print("Invalid initial link: $e");
          }
        }
      }
    });
  }

  void _initDeepLinks() {
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      handleDeepLink(uri);
    });
  }

  Future<void> handleDeepLink(Uri uri) async {
    // tryb://join/<hostUid>
    if (uri.scheme == 'tryb' && uri.host == 'join') {
      if (onDeepLink != null) onDeepLink!(uri);
    }
  }

  Future<void> _checkRejoin() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    try {
      final event = await FirebaseDatabase.instance.ref('users/$uid').once();
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final gameId = data['currentGameId'];
        final tableId = data['currentTableId'];

        if (gameId != null && tableId != null) {
          // Verify active
          final gameSnap =
              await FirebaseDatabase.instance.ref('games/$gameId').get();
          final gameData = gameSnap.value;
          String? state;
          if (gameData is Map) {
            state = gameData['state'];
          } else if (gameData is String) state = gameData;

          if (state == 'active') {
            // Check if I have left/forfeited this game?
            final gameMap = gameData as Map<Object?, Object?>;
            final rawPlayers = gameMap['players'];
            if (rawPlayers is Map) {
              final myData = rawPlayers[uid];
              if (myData != null && myData is Map) {
                final status = myData['status'];
                if (status == 'left' || status == 'kicked') {
                  debugPrint('REJOIN: Skipped game $gameId (Status: $status)');
                  return;
                }
              }
            }

            debugPrint('REJOIN: Found active game $gameId');
            if (onRejoinGame != null) onRejoinGame!(gameId, tableId);
          }
        }
      }
    } catch (e) {
      print("REJOIN ERROR: $e");
    }
  }

  // --- ACTIONS ---

  Future<void> joinQueueFlow(
      {required int fee, required String matchMode}) async {
    if (!_context.mounted) return;

    // 1. Show Pay Modal
    showDialog(
      context: _context,
      builder: (_) => PayModal(
        entryText:
            '${fee >= 1000 ? (fee / 1000).toStringAsFixed(1) + 'k' : fee} Gold',
        onJoin: () async {
          Navigator.of(_context).pop(); // Close Pay Modal

          // 2. Show Waiting / Matchmaking Modal
          await showWaitingMatchModal(
            context: _context,
            entryFee: fee,
            mockMode: false,
            mode: matchMode,
          );
        },
      ),
    );
  }

  Future<void> handlePublishTable() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('publishTable').call();
    } catch (e) {
      debugPrint("Failed to publish table: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinQueue(
      {required String pushId,
      required int entryFee,
      required int gemFee,
      required String hostUid}) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('pickPlayerFromQueue')
        .call({
      'targetPushId': pushId,
      'gemFee': gemFee,
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String> inviteFriendLink() async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    return "https://tryb-ludo-v1.web.app/invite?code=$uid";
  }

  Future<String> sendGuestInvite(String hostUid) async {
    // Helper to call backend
    return await _inviteService.sendInvite(hostUid);
  }

  // Age Gate Logic
  bool? _ageConfirmed;
  bool _isUnderage = false;

  bool? get ageConfirmed => _ageConfirmed;
  bool get isUnderage => _isUnderage;

  Future<void> verifyAge(int birthYear) async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;
    final currentYear = DateTime.now().year;
    final age = currentYear - birthYear;

    if (age >= 13) {
      // Eligible
      await FirebaseDatabase.instance.ref('users/$uid/flags').update({
        'ageVerified': true,
        'birthYear': birthYear,
        'ageVerifiedAt': ServerValue.timestamp,
        'isUnderage': false,
      });
      _ageConfirmed = true;
      _isUnderage = false;
      notifyListeners();
    } else {
      // Ineligible
      await FirebaseDatabase.instance.ref('users/$uid/flags').update({
        'ageVerified': false,
        'isUnderage': true,
        'birthYear': birthYear,
        'blockedAt': ServerValue.timestamp,
      });

      _isUnderage = true;
      _ageConfirmed = false;
      notifyListeners();

      // Blocking logic: Sign out
      await Future.delayed(const Duration(milliseconds: 2000));
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _checkAgeStatus() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;

    final event = await FirebaseDatabase.instance.ref('users/$uid/flags').get();
    final flags = event.value as Map?;
    debugPrint("AGE CHECK: uid=$uid, flags=$flags"); // DEBUG LOG

    if (flags != null) {
      // Strict Age Verification (Epic A)
      // We now check for 'ageVerified' (the new flag) instead of 'ageConfirmed'.
      // If 'ageVerified' is true, we map it to _ageConfirmed so UI unblocks.
      _ageConfirmed = flags['ageVerified'] == true;
      _isUnderage = flags['isUnderage'] == true;
    } else {
      // Default to NULL (Show Gate)
      _ageConfirmed = null;
      _isUnderage = false;
    }
    notifyListeners();
  }
}
