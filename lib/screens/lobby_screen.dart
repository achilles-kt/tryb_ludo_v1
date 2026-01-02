import 'package:flutter/material.dart';

import 'package:firebase_database/firebase_database.dart';

import '../widgets/modals/gem_pay_modal.dart'; // Restored

// Used in LobbyQueueList/ActiveList but invalid here if not used directly?
// Actually LobbyActiveList uses TableCard, LobbyScreen does not?
// LobbyScreen checks LobbyQueueList imports.
// Wait, LobbyScreen does NOT use TableCard directly.
// import '../widgets/onboarding/age_gate_overlay.dart'; // Removed
import 'game_screen.dart';

// Restored
// Restored
import '../controllers/lobby_controller.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

import '../widgets/modals/invite_waiting_modal.dart';
import '../widgets/modals/profile_edit_modal.dart';
import '../widgets/lobby/lobby_top_bar.dart';
import '../widgets/lobby/lobby_header.dart';
import '../widgets/lobby/lobby_queue_list.dart';
import '../widgets/lobby/lobby_active_list.dart';
import '../widgets/lobby/reward_overlay_wrapper.dart'; // Restored
import '../widgets/onboarding/age_verification_overlay.dart';
import '../widgets/lobby/lobby_floating_controls.dart';
import '../widgets/lobby/matchmaking_sheet.dart';

class LobbyScreen extends StatefulWidget {
  final String? initialDeepLink;
  const LobbyScreen({super.key, this.initialDeepLink});
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final LobbyController _controller = LobbyController();
  // Keep local refs for UI convenience if needed, or read from controller

  @override
  void initState() {
    super.initState();

    // Setup Controller
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.onRejoinGame = (gameId, tableId) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(gameId: gameId, tableId: tableId),
        ),
      );
    };

    _controller.onDeepLink = (uri) {
      _handleDeepLink(uri);
    };

    _controller.init(context, widget.initialDeepLink);
  }

  void _openProfileModal(String currentName, String currentAvatar,
      String currentCity, String currentCountry) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54, // Semi-transparent bg
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ProfileEditModal(
          currentName: currentName,
          currentAvatar: currentAvatar,
          currentCity: currentCity,
          currentCountry: currentCountry,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Wrap entire Lobby in InviteOverlay to listen for invites
    if (!_controller.authReady || _controller.currentUser == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width > 420
            ? 390.0
            : MediaQuery.of(context).size.width,
        height: 844,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Main Content
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _topBar(),
                  const LobbyHeader(),
                  Expanded(child: _lobbyContent()),
                ],
              ),
            ),

            // Floating Controls
            LobbyFloatingControls(
              onPlayTap: () => MatchmakingSheet.show(context, _controller),
            ),

            // Age Verification Overlay (Epic A)
            // Shows if ageConfirmed is null (new/unverified) or false.
            // Shows if enabled in config AND ageConfirmed is null/false
            if (_controller.currentUser != null &&
                ConfigService.instance.ageVerificationEnabled &&
                (_controller.ageConfirmed == false ||
                    _controller.ageConfirmed == null) &&
                !_controller.isUnderage)
              AgeVerificationOverlay(
                onYearSelected: (year) => _controller.verifyAge(year),
              ),

            // Blocked Screen (if isUnderage)
            if (_controller.isUnderage)
              Container(
                color: AppTheme.bgDark,
                child: const Center(
                  child: Text(
                    "Access Denied.\nTryb is restricted to users 13+.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Revised Guest Flow (Send Invite -> Wait) ---
  void _handleDeepLink(Uri uri) {
    final myUid = _controller.currentUser?.uid;
    // Format: tryb://join/<hostUid>
    if (uri.scheme == 'tryb' && uri.host == 'join') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final hostUid = segments.first;
        if (hostUid == myUid) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("You cannot join your own link.")));
          return;
        }
        _initiateGuestInvite(hostUid);
      }
    }
  }

  void _initiateGuestInvite(String hostUid) async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2025),
              title: const Text("Join Friend?",
                  style: TextStyle(color: Colors.white)),
              content: const Text("Send a request to play?",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Send Request")),
              ],
            ));

    if (confirm != true) return;

    // 2. Send Invite
    try {
      // Show loading
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));

      final inviteId = await _controller.sendGuestInvite(hostUid);

      Navigator.pop(context); // Pop loading

      // 3. Show Waiting Modal (Robust Handshake)
      // This modal listens to the invite status.
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InviteWaitingModal(inviteId: inviteId, isHost: false),
      ).then((result) {
        if (result != null && result is Map) {
          if (result['accepted'] == true) {
            // Navigate to Game
            final gameId = result['gameId'];
            final tableId = result['tableId'];
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GameScreen(gameId: gameId, tableId: tableId)));
          }
        }
      });
    } catch (e) {
      Navigator.pop(context); // Pop loading
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to send invite: $e")));
    }
  }

  Widget _topBar() {
    return LobbyTopBar(
        currentUser: _controller.currentUser,
        onProfileTap: (name, avatar, city, country) {
          _openProfileModal(name, avatar, city, country);
        });
  }

  Widget _lobbyContent() {
    return RewardOverlayWrapper(
        currentUid: _controller.currentUser?.uid,
        child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('queue/2p').onValue,
            builder: (context, queueSnap) {
              return StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref('tables')
                      .orderByChild('status')
                      .equalTo('active')
                      .onValue,
                  builder: (context, tablesSnap) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 160),
                              children: [
                                // 1. Waiting Tables (Queue)
                                LobbyQueueList(
                                    queueSnap: queueSnap,
                                    currentUid: _controller.currentUser?.uid,
                                    onJoin:
                                        (pushId, entryFee, gemFee, hostUid) {
                                      _handleQueueJoin(
                                          pushId, entryFee, gemFee, hostUid);
                                    }),

                                // 2. Active Tables (Spectate)
                                LobbyActiveList(
                                  tablesSnap: tablesSnap,
                                  currentUid: _controller.currentUser?.uid,
                                  onJoinQueue: (fee, mode) => _controller
                                      .joinQueueFlow(fee: fee, matchMode: mode),
                                  onSpectate: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Joining live tables coming soon!")));
                                  },
                                ),

                                const SizedBox(height: 100), // Bottom padding
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  });
            }));
  }

  void _handleQueueJoin(
      String pushId, int entryFee, int gemFee, String hostUid) {
    debugPrint(
        'Table Card Join clicked | ${_controller.currentUser?.uid} | $hostUid');
    showDialog(
      context: context,
      builder: (_) => GemPayModal(
        entryFee: entryFee,
        gemFee: gemFee,
        onConfirm: () async {
          Navigator.of(context).pop(); // Close modal

          // Call Controller
          try {
            final result = await _controller.joinQueue(
                pushId: pushId,
                entryFee: entryFee,
                gemFee: gemFee,
                hostUid: hostUid);

            final gameId = result['gameId'];
            final tableId = result['tableId'];

            if (gameId != null && tableId != null && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    gameId: gameId,
                    tableId: tableId,
                  ),
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Failed to join: $e"),
                  backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }
}
