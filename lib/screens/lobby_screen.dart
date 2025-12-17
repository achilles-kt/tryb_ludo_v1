import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/gem_pay_modal.dart';
import '../constants.dart';
import '../widgets/table_card.dart';
import '../widgets/bottom_chat_pill.dart';
import '../widgets/play_sheet.dart';
import '../widgets/pay_modal.dart';
import 'game_screen.dart';
import '../widgets/waiting_match_modal.dart';
import '../widgets/gold_balance_widget.dart';
import '../widgets/gem_balance_widget.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import '../widgets/private_table_sheet.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:async';
import '../services/config_service.dart';
import 'package:app_links/app_links.dart';

import '../services/invite_service.dart';
import '../widgets/invite_overlay.dart';
import '../widgets/invite_waiting_modal.dart';

class LobbyScreen extends StatefulWidget {
  final String? initialDeepLink;
  const LobbyScreen({Key? key, this.initialDeepLink}) : super(key: key);
  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  bool playSheetOpen = false;
  bool bgChatVisible = true;

  late AnimationController _bgController;
  final InviteService _inviteService = InviteService();
  final ChatService _chatService = ChatService();
  StreamSubscription? _chatSub;
  final List<ChatMessage> _floatingMessages = [];
  bool _authReady = false;
  User? _currentUser;
  StreamSubscription? _authSub;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

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

    _chatSub = _chatService.getGlobalChat().listen((messages) {
      if (mounted) {
        setState(() {
          final now = DateTime.now().millisecondsSinceEpoch;
          // Filter out messages older than 2 minutes (120000ms)
          final relevant =
              messages.where((m) => (now - m.timestamp) < 120000).toList();

          // Show last 5
          final count = relevant.length;
          final lastFew = relevant.sublist(count > 5 ? count - 5 : 0);

          _floatingMessages.clear();
          _floatingMessages.addAll(lastFew);
        });
      }
    });

    // Cleanup timer to remove expired messages periodically
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_floatingMessages.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final expired =
          _floatingMessages.where((m) => (now - m.timestamp) > 120000).toList();

      if (expired.isNotEmpty && mounted) {
        setState(() {
          _floatingMessages.removeWhere((m) => (now - m.timestamp) > 120000);
        });
      }
    });
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

  @override
  void dispose() {
    _bgController.dispose();
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

    return InviteOverlay(
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Container(
            width: MediaQuery.of(context).size.width > 420
                ? 390.0
                : MediaQuery.of(context).size.width,
            height: 844,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: AppColors.neonPurple.withOpacity(0.12),
                    blurRadius: 50)
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _buildBgChat()),
                Column(
                  children: [
                    const SizedBox(height: 20),
                    _topBar(),
                    Expanded(child: _lobbyContent()),
                  ],
                ),
                Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(child: _playBtn())),
                const Positioned(
                    bottom: 0, left: 0, right: 0, child: BottomChatPill()),
              ],
            ),
          ),
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

  Widget _buildBgChat() {
    if (_floatingMessages.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: _floatingMessages.asMap().entries.map((entry) {
          final i = entry.key;
          final msg = entry.value;
          final isLeft = i % 2 == 0;
          final delay = (i * 2.5) % 8.0;

          return _floatingMsg(
              left: isLeft ? 20.0 + (i * 10) : null,
              right: !isLeft ? 20.0 : null,
              delay: delay,
              avatar: 'assets/avatars/a${(msg.senderId.hashCode % 5) + 1}.png',
              text: msg.text,
              sender: msg.senderName);
        }).toList(),
      ),
    );
  }

  Widget _floatingMsg(
      {double? left,
      double? right,
      required double delay,
      required String avatar,
      required String text,
      String? sender}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        final t = (_bgController.value + (delay / 8)) % 1.0;
        final startY = 820.0;
        final endY = 120.0;
        final y = startY - (startY - endY) * t;
        final opacity = (t < 0.1)
            ? (t * 10)
            : (t > 0.8)
                ? (1 - (t - 0.8) * 5)
                : 0.8;

        if (opacity <= 0) return const SizedBox.shrink();

        return Positioned(
          left: left,
          right: right,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 9, backgroundImage: AssetImage(avatar)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sender != null)
                        Text(sender,
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.white.withOpacity(0.5))),
                      Text(
                          text.length > 20
                              ? '${text.substring(0, 20)}...'
                              : text,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Stack(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/avatars/a1.png',
                      width: 48, height: 48, fit: BoxFit.cover)),
              Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGrad,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Center(
                        child: Text('12',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                  ))
            ]),
            const SizedBox(width: 12),
            StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('users/${_currentUser?.uid}/profile')
                    .onValue,
                builder: (context, snapshot) {
                  final data = snapshot.data?.snapshot.value as Map?;
                  final name = data?['displayName'] ?? 'New User';
                  final city = data?['city'] ?? '';
                  final country = data?['country'] ?? 'India';
                  final location =
                      city.toString().isEmpty ? country : '$city, $country';

                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(location,
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8))),
                      ]);
                })
          ]),
          // Currency Balances
          Row(
            children: const [
              GemBalanceWidget(),
              SizedBox(width: 8),
              GoldBalanceWidget(),
            ],
          ),
        ],
      ),
    );
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
                      _clubHeader(),
                      const SizedBox(height: 10),
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

  void _buildQueueList(List<Widget> listItems,
      AsyncSnapshot<DatabaseEvent> queueSnap, String? myUid) {
    final queueData = queueSnap.data?.snapshot.value as Map?;
    if (queueData != null) {
      queueData.forEach((key, value) {
        final val = value as Map;
        final uid = val['uid'];
        if (uid == myUid) return; // Don't show self

        print('Table card in Lobby visible | $myUid | $uid');
        listItems.add(
          TableCard(
            mode: '2P',
            winText: 'WAITING FOR OPPONENT',
            entryFee: ConfigService.instance.gameStake,
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

        listItems.add(_buildActiveMatchCard(val));
        listItems.add(const SizedBox(height: 12));
      });
    }
  }

  void _buildQuickPlayCards(List<Widget> listItems) {
    int currentCount = (listItems.length / 2).ceil();
    if (currentCount < 5) {
      listItems.add(TableCard(
        mode: '2P',
        winText: 'WIN ${ConfigService.instance.gameStake * 2} GOLD',
        entryFee: ConfigService.instance.gameStake,
        onTap: () =>
            _showQuickJoinModal(ConfigService.instance.gameStake, '2p'),
      ));
      listItems.add(const SizedBox(height: 12));

      listItems.add(TableCard(
        mode: 'TEAM',
        winText: 'WIN 5K GOLD',
        entryLabel: '2.5k Gold',
        onTap: () => _showQuickJoinModal(2500, 'team'),
      ));
      listItems.add(const SizedBox(height: 12));
    }
  }

  void _handleQueueJoin(
      String pushId, int entryFee, int gemFee, String hostUid) {
    print('Table Card Join clicked | ${_currentUser?.uid} | $hostUid');
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
            gradient: AppColors.primaryGrad,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neonPurple.withOpacity(0.28),
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

  Widget _buildActiveMatchCard(Map tableData) {
    // default stake ConfigService.instance.gameStake
    final stake = tableData['stake'] ?? ConfigService.instance.gameStake;
    // Safely get spectators count (map or list)
    int spectatorCount = 0;
    final specData = tableData['spectators'];
    if (specData is Map) {
      spectatorCount = specData.length;
    } else if (specData is List) {
      spectatorCount = specData.length;
    }

    // Status Text
    String statusText = 'Active';
    if (spectatorCount > 0) {
      statusText = 'Watching ($spectatorCount)';
    }

    // For now simple P1 vs P2.
    // In real app we fetch names/avatars.
    // Using placeholders.

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025)
            .withOpacity(0.7), // Glass surface equivalent
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.7))),
                child: Text('2P',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.7))),
              ),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGrad.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                child: Text('WIN ${stake * 2} GOLD',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            Colors.white)), // color ignored by mask but needed
              )
            ],
          ),
          const SizedBox(height: 12),
          // VS Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // P1
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFF2D3748), width: 2),
                      image: const DecorationImage(
                          image: AssetImage('assets/avatars/a1.png'),
                          fit: BoxFit.cover)),
                ),
                // VS
                Text('VS',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic)),
                // P2
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFF2D3748), width: 2),
                      image: const DecorationImage(
                          image: AssetImage('assets/avatars/a2.png'),
                          fit: BoxFit.cover)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Footer
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Entry: $stake Gold',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
                Text(statusText,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          )
        ],
      ),
    );
  }

  // <-- NEW: club header implementation (was missing)
  Widget _clubHeader() {
    return Column(
      children: [
        Text('Tryb',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            SizedBox(width: 6),
            CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text('425 Online',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
        ),
      ],
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
