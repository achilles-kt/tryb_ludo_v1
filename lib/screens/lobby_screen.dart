import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/gem_pay_modal.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/table_card.dart';
import '../widgets/bottom_chat_pill.dart';
import '../widgets/play_sheet.dart';
import '../widgets/pay_modal.dart';
import 'game_screen.dart';
import '../widgets/waiting_match_modal.dart';
import '../services/chat_service.dart';
import '../models/activity_item.dart';
import '../widgets/private_table_sheet.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:async';
import '../services/config_service.dart';
import 'package:app_links/app_links.dart';

import '../services/invite_service.dart';
import '../widgets/invite_waiting_modal.dart';
import '../widgets/profile_edit_modal.dart';
import '../widgets/lobby/lobby_top_bar.dart';
import '../widgets/lobby/lobby_header.dart';
import '../utils/currency_formatter.dart';

class LobbyScreen extends StatefulWidget {
  final String? initialDeepLink;
  const LobbyScreen({Key? key, this.initialDeepLink}) : super(key: key);
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  bool playSheetOpen = false;
  final InviteService _inviteService = InviteService();
  final ActivityService _chatService = ActivityService();
  StreamSubscription? _chatSub;
  bool _authReady = false;
  User? _currentUser;
  StreamSubscription? _authSub;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    // Listen to Auth State logic
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _authReady = true;
        });

        if (user != null) {
          // Check for Rejoin
          FirebaseDatabase.instance
              .ref('users/${user.uid}')
              .once()
              .then((event) {
            final data = event.snapshot.value as Map?;
            if (data != null) {
              final gameId = data['currentGameId'];
              final tableId = data['currentTableId'];
              if (gameId != null && tableId != null) {
                // Validate Game Status
                try {
                  FirebaseDatabase.instance
                      .ref('games/$gameId')
                      .get()
                      .then((gameSnap) {
                    final gameData = gameSnap.value;
                    String? state;

                    if (gameData is Map) {
                      state = gameData['state'] as String?;
                    } else if (gameData is String) {
                      state =
                          gameData; // Fallback if it was just the state string
                    }

                    if (state == 'active') {
                      print(
                          'REJOIN: Automatically joining active game $gameId');
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GameScreen(gameId: gameId, tableId: tableId),
                          ),
                        );
                      }
                    } else {
                      print(
                          'REJOIN: Game $gameId state is $state. (Data: $gameData). Ignoring.');
                    }
                  }).catchError((e) {
                    print("REJOIN ERROR: Failed to check game state: $e");
                  });
                } catch (e) {
                  print("REJOIN ERROR: Synchronous error: $e");
                }
              }
            }
          });
        }

        if (user != null) {
          _checkRewards(); // Now safe to check

          // Deep link check
          if (widget.initialDeepLink != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final uri = Uri.parse(widget.initialDeepLink!);
                _handleDeepLink(uri);
              } catch (e) {
                print("Invalid initial link: $e");
              }
            });
          }
        }
      }
    });

    _initDeepLinks();

    // _initFCM(); // Handled by InviteOverlay via DB stream
    // Chat listener removed for now
  }

  void _checkRewards() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseDatabase.instance.ref('walletTransactions/$uid');

    // Listen once (or stream, but once is usually enough for startup check)
    // Actually, onUserCreate might take a second, so a stream is safer for "instant" gratifying
    // or just listen to child_added.
    ref
        .orderByChild('meta/reason')
        .equalTo('initial_rewards')
        .onChildAdded
        .listen((event) {
      final val = event.snapshot.value as Map?;
      if (val != null) {
        final meta = val['meta'] as Map?;
        final seen = meta?['seen'] == true;

        if (!seen) {
          // Show Reward!
          final amount = val['amount']; // could be gold number or gems number
          final currency = val['currency'] ?? 'gold'; // 'gold' or 'gems'

          if (mounted) {
            _showRewardOverlay(event.snapshot.key!, amount, currency);
          }
        }
      }
    }, onError: (e) {
      print("Rewards check error: $e");
    });
  }

  void _showRewardOverlay(String txnKey, dynamic amount, String currency) {
    if (!mounted) return;

    // Mark as seen immediately to avoid loop, or after close.
    // Ideally after close, but for safety let's do it after we show dialog.
    final uid = _currentUser?.uid;
    if (uid != null) {
      FirebaseDatabase.instance
          .ref('walletTransactions/$uid/$txnKey/meta/seen')
          .set(true);
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          gradient: AppColors.primaryGrad,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.neonPurple.withOpacity(0.5),
                                blurRadius: 40)
                          ]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "WELCOME GIFT!",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 20),
                          // Icon
                          Image.asset(
                            currency == 'gems'
                                ? 'assets/imgs/gem.png'
                                : 'assets/imgs/coin.png', // Ensure these assets exist or use Icon for now if missing
                            width: 80, height: 80,
                            errorBuilder: (c, o, s) => Icon(
                                currency == 'gems'
                                    ? Icons.diamond
                                    : Icons.monetization_on,
                                size: 80,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text("+$amount ${currency.toUpperCase()}",
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amberAccent,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black45,
                                        offset: Offset(2, 2),
                                        blurRadius: 4)
                                  ])),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.purple,
                                  shape: StadiumBorder()),
                              onPressed: () => Navigator.pop(context),
                              child: const Text("AWESOME!"))
                        ],
                      ),
                    ),
                  );
                },
              ),
            ));
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
    _authSub?.cancel();
    _chatSub?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void openPlaySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14161b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => PlayOptionsSheet(onSelect: (mode) async {
        Navigator.of(context).pop();

        if (mode == 'create_2p') {
          // Show Private Table Options
          showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF14161b),
              builder: (ctx) => PrivateTableSheet(onPublish: () {
                    Navigator.pop(ctx);
                    _handlePublishTable();
                  }, onInvite: () {
                    Navigator.pop(ctx);
                    _handleInviteFriend();
                  }));
        } else if (mode == '2p') {
          showDialog(
            context: context,
            builder: (_) => PayModal(
              entryText: '500 Gold',
              onJoin: () async {
                Navigator.of(context).pop(); // Close PayModal
                // Show matchmaking modal
                final result = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      WaitingMatchModal(entryFee: 500, mockMode: false),
                );

                // Navigate to game if matched
                if (result != null) {
                  final gameId = result['gameId'] as String?;
                  final tableId = result['tableId'] as String?;

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
                }
              },
            ),
          );
        } else if (mode == 'team') {
          showDialog(
              context: context,
              builder: (_) => PayModal(
                  entryText: '2.5k Gold',
                  onJoin: () async {
                    Navigator.of(context).pop();

                    final result =
                        await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => WaitingMatchModal(
                          entryFee: 2500, mockMode: false, mode: '4p'),
                    );

                    if (result != null) {
                      final gameId = result['gameId'] as String?;
                      final tableId = result['tableId'] as String?;

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
                    }
                  }));
        }
      }),
    );
  }

  void _handlePublishTable() {
    // Same as Join 2P but conceptually "creating" a spot
    // Currently our queue logic is unified (everyone joins queue)
    // So we just trigger the Join 2P flow
    showDialog(
        context: context,
        builder: (_) => PayModal(
            entryText: '500 Gold',
            onJoin: () async {
              Navigator.of(context).pop();
              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    WaitingMatchModal(entryFee: 500, mockMode: false),
              );

              if (result != null) {
                final gameId = result['gameId'] as String?;
                final tableId = result['tableId'] as String?;

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
              }
            }));
  }

  @override
  Widget build(BuildContext context) {
    // 1. Wrap entire Lobby in InviteOverlay to listen for invites
    if (!_authReady || _currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
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
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Background decorations moved or simplified

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
            Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                height: 120, // Constrain height to avoid blocking top touches
                child: Center(child: _playBtn())),
            const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100, // Constrain height
                child: BottomChatPill()),
          ],
        ),
      ),
    );
  }

  // --- Revised Host Flow (No backend call needed initially) ---
  void _handleInviteFriend() async {
    final myUid = _currentUser?.uid;
    print("1. Host click invite friend | UID: $myUid");

    if (myUid == null) return;

    try {
      // 1. Generate Link with just UID
      // funds are checked/deducted when Host accepts.
      final link = "https://tryb-ludo-v1.web.app/invite?code=$myUid";

      // 2. Show Invite Dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2025),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Invite Friend",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Share this link with your friend to play!",
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  link,
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontFamily: 'Courier'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Copy Button
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Link copied to clipboard!"),
                                duration: Duration(seconds: 1)),
                          );
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.copy, color: Colors.white),
                        padding: EdgeInsets.zero,
                      ),
                      const Text("Copy",
                          style: TextStyle(color: Colors.white70, fontSize: 12))
                    ],
                  ),
                  // Share Button
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Share.share(
                              "Play Ludo with me! Click here to join: $link");
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.share,
                            color: Colors.lightGreenAccent),
                        padding: EdgeInsets.zero,
                      ),
                      const Text("Share",
                          style: TextStyle(color: Colors.white70, fontSize: 12))
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      );
    } catch (e) {
      print("Share error: $e");
    }
  }

  // --- Revised Guest Flow (Send Invite -> Wait) ---
  void _handleDeepLink(Uri uri) {
    print("Link Recieved: $uri");
    final myUid = _currentUser?.uid;
    print("Guest Link click | UID: $myUid");

    // Format: tryb://join/<hostUid>
    if (uri.scheme == 'tryb' && uri.host == 'join') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final hostUid = segments.first;
        if (hostUid == myUid) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("You cannot join your own link.")));
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
              backgroundColor: Color(0xFF1E2025),
              title:
                  Text("Join Friend?", style: TextStyle(color: Colors.white)),
              content: Text("Send a request to play?",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text("Send Request")),
              ],
            ));

    if (confirm != true) return;

    // 2. Send Invite
    try {
      // Show loading
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(child: CircularProgressIndicator()));

      final inviteId = await _inviteService.sendInvite(hostUid);

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

  // Legacy/Unused methods removed or commented out to avoid confusion
  // _joinPrivateGame, _handleInviteNotification (replaced by Overlay)

  Widget _topBar() {
    return LobbyTopBar(
        currentUser: _currentUser,
        onProfileTap: (name, avatar, city, country) {
          _openProfileModal(name, avatar, city, country);
        });
  }

  Widget _lobbyContent() {
    return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('queue/2p').onValue,
        builder: (context, queueSnap) {
          return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('tables')
                  .orderByChild('status')
                  .equalTo('active')
                  .onValue,
              builder: (context, tablesSnap) {
                final List<Widget> listItems = [];
                final myUid = _currentUser?.uid;

                // 1. Waiting Tables (Queue)
                _buildQueueList(listItems, queueSnap, myUid);

                // 2. Active Tables (Spectate)
                _buildActiveList(listItems, tablesSnap, myUid);

                // 3. Quick Play Cards (if list is short)
                _buildQuickPlayCards(listItems);

                return Padding(
                  padding: const EdgeInsets.only(
                      top: 8, left: 16, right: 16, bottom: 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 160),
                          children: [
                            ...listItems,
                            const SizedBox(height: 50),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              });
        });
  }

  // Wait, I messed up the replacement block logic above.
  // I should replace `_clubHeader` definition AND `_lobbyContent` definition logic.
  // BUT they might not be contiguous.
  // Safe bet: Replace `_clubHeader` first. Then `_buildActiveList` to parse avatars.

  // Let's Cancel this big block and do it piecewise.
  // 1. Update `_clubHeader`.
  // 2. Update `_buildActiveList`.

  void _buildQueueList(List<Widget> listItems,
      AsyncSnapshot<DatabaseEvent> queueSnap, String? myUid) {
    final queueData = queueSnap.data?.snapshot.value as Map?;
    if (queueData != null) {
      queueData.forEach((key, value) {
        final val = value as Map;
        final uid = val['uid'];
        if (uid == myUid) return; // Don't show self

        listItems.add(
          TableCard(
            mode: '2P',
            winText: 'WIN ${ConfigService.instance.gameStake * 2} GOLD',
            entryFee: ConfigService.instance.gameStake,
            isActive: false, // It's a queue item, not active game
            isTeam: false,
            onTap: () => _handleQueueJoin(key, ConfigService.instance.gameStake,
                ConfigService.instance.gemFee, uid),
          ),
        );
        listItems.add(const SizedBox(height: 12));
      });
    }
  }

  void _buildActiveList(List<Widget> listItems,
      AsyncSnapshot<DatabaseEvent> tablesSnap, String? myUid) {
    final tablesData = tablesSnap.data?.snapshot.value as Map?;
    if (tablesData != null) {
      tablesData.forEach((key, value) {
        final val = value as Map;
        final players = val['players'] as Map?;

        if (players != null && myUid != null) {
          if (players.containsKey(myUid)) return; // Hide self
        }

        // Convert table data to Card
        final stake = val['stake'] ?? ConfigService.instance.gameStake;
        final isTeam = val['mode'] == '4p' || val['mode'] == 'team';

        listItems.add(TableCard(
            mode: isTeam ? 'TEAM' : '2P',
            winText: 'WIN ${stake * 2} GOLD', // Approximate win text
            entryFee: stake, // Show fee even if active
            isActive: true,
            isTeam: isTeam,
            onTap: () {
              // Spectate Logic or "Full" toast
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Spectating coming soon!")));
            }));
        listItems.add(const SizedBox(height: 12));
      });
    }
  }

  void _buildQuickPlayCards(List<Widget> listItems) {
    int currentCount = (listItems.length / 2).ceil();
    if (currentCount < 5) {
      // 1. Classic 1v1
      listItems.add(TableCard(
        mode: '2P',
        winText: 'WIN ${ConfigService.instance.gameStake * 2} GOLD',
        entryFee: ConfigService.instance.gameStake,
        isActive: false,
        isTeam: false,
        onTap: () =>
            _showQuickJoinModal(ConfigService.instance.gameStake, '2p'),
      ));
      listItems.add(const SizedBox(height: 12));

      // 2. Team 2v2
      listItems.add(TableCard(
        mode: 'TEAM',
        winText: 'WIN 5K GOLD',
        entryLabel: '2.5k Gold',
        // Special case for manual label if needed, but entryFee int is preferred usually
        entryFee: 2500,
        isActive: false,
        isTeam: true,
        onTap: () => _showQuickJoinModal(2500, 'team'),
      ));
      listItems.add(const SizedBox(height: 12));
    }
  }

  void _handleQueueJoin(
      String pushId, int entryFee, int gemFee, String hostUid) {
    debugPrint('Table Card Join clicked | ${_currentUser?.uid} | $hostUid');
    showDialog(
      context: context,
      builder: (_) => GemPayModal(
        entryFee: entryFee,
        gemFee: gemFee,
        onConfirm: () async {
          Navigator.of(context).pop(); // Close modal

          // Call Backend
          try {
            // Show loading overlay?
            // For simplicity, just awaiting.
            final result = await FirebaseFunctions.instance
                .httpsCallable('pickPlayerFromQueue')
                .call({
              'targetPushId': pushId,
              'gemFee': gemFee,
            });

            final data = result.data as Map;
            final gameId = data['gameId'];
            final tableId = data['tableId'];

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

  void _showQuickJoinModal(int fee, String mode) {
    showDialog(
        context: context,
        builder: (_) => PayModal(
            entryText: mode == 'team'
                ? '2.5k Gold'
                : '${ConfigService.instance.gameStake} Gold',
            onJoin: () async {
              Navigator.of(context).pop();
              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => WaitingMatchModal(
                    entryFee: fee,
                    mockMode: false,
                    mode: mode == 'team' ? '4p' : '2p'),
              );

              if (result != null) {
                final gameId = result['gameId'] as String?;
                final tableId = result['tableId'] as String?;

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
              }
            }));
  }

  Widget _playBtn() {
    return GestureDetector(
      onTap: openPlaySheet,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
            gradient: AppTheme.primaryGrad,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.neonPurple.withOpacity(0.28),
                  blurRadius: 40,
                  offset: const Offset(0, 10))
            ],
            border:
                Border.all(color: Colors.white.withOpacity(0.12), width: 3)),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.play_arrow, color: Colors.white, size: 32),
              SizedBox(height: 4),
              Text('PLAY',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: Colors.white))
            ]),
      ),
    );
  }

  void _initDeepLinks() {
    final _appLinks = AppLinks();

    // Check initial link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to stream
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }
}
