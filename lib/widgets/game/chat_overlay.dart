import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/activity_item.dart';
import '../../services/chat_service.dart';
import 'flying_bubble.dart';

class ChatOverlay extends StatefulWidget {
  final String gameId;
  final Map<String, dynamic> players;
  final int localPlayerIndex;
  final Rect boardRect;

  const ChatOverlay({
    super.key,
    required this.gameId,
    required this.players,
    required this.localPlayerIndex,
    required this.boardRect,
  });

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  final ActivityService _chatService = ActivityService();
  StreamSubscription? _chatSub;

  // Track active bubbles by Sender ID to ensure only 1 per user
  final Map<String, ActivityItem> _activeBubbles = {};
  final Map<String, Timer> _bubbleTimers = {};
  final List<Map<String, dynamic>> _flyingEmojis = [];
  final Set<String> _processedMsgIds = {};

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔍 Chat: Overlay Init | GameID: ${widget.gameId} | LocalPlayer: ${widget.localPlayerIndex}');

    // Determine Conversation IDs to listen to
    final allUids = widget.players.keys.toList();
    final gpId = _chatService.getCanonicalId(allUids);

    // Team Chat
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String? teamId;
    if (myUid != null && widget.players.containsKey(myUid)) {
      final myTeam = widget.players[myUid]['team'];
      if (myTeam != null) {
        final teamUids = widget.players.entries
            .where((e) => e.value['team'] == myTeam)
            .map((e) => e.key)
            .toList();
        if (teamUids.length > 1) {
          teamId = _chatService.getCanonicalId(teamUids);
        }
      }
    }

    final ids = [gpId];
    if (teamId != null && teamId != gpId) {
      ids.add(teamId);
    }

    debugPrint('🔍 Chat: Listening to Unified Streams: $ids');

    // Phase 14 Fix: Ensure conversations exist before listening
    _ensureAndListen(ids, allUids, myUid);
  }

  Future<void> _ensureAndListen(
      List<String> ids, List<String> allUids, String? myUid) async {
    // 1. Ensure Global Group
    if (ids.contains(_chatService.getCanonicalId(allUids))) {
      await _chatService.ensureConversation(allUids);
    }

    // 2. Ensure Team DM
    if (myUid != null && widget.players.containsKey(myUid)) {
      final myTeam = widget.players[myUid]['team'];
      if (myTeam != null) {
        final teamUids = widget.players.entries
            .where((e) => e.value['team'] == myTeam)
            .map((e) => e.key)
            .toList();
        if (teamUids.length > 1) {
          final teamId = _chatService.getCanonicalId(teamUids);
          if (ids.contains(teamId)) {
            await _chatService.ensureConversation(teamUids);
          }
        }
      }
    }

    if (!mounted) return;

    // 3. Listen
    _chatSub = _chatService.getMergedActivityStream(ids).listen((messages) {
      if (messages.isEmpty) return;
      _handleNewMessages(messages);
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    for (var t in _bubbleTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if players list changed (count or keys)
    // Simple check: Length or String representation of keys
    /*
      Ideally we check if the set of IDs we need to listen to has changed.
    */
    final oldKeys = oldWidget.players.keys.toSet();
    final newKeys = widget.players.keys.toSet();

    if (oldKeys.length != newKeys.length || !oldKeys.containsAll(newKeys)) {
      debugPrint("🔍 Chat: Players changed, refreshing stream...");
      _refreshStreamSubscription();
    }
  }

  void _refreshStreamSubscription() {
    _chatSub?.cancel();

    // Re-Determine Conversation IDs
    final allUids = widget.players.keys.toList();
    final gpId = _chatService.getCanonicalId(allUids);

    // Team Chat
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    String? teamId;
    if (myUid != null && widget.players.containsKey(myUid)) {
      final myTeam = widget.players[myUid]['team'];
      if (myTeam != null) {
        final teamUids = widget.players.entries
            .where((e) => e.value['team'] == myTeam)
            .map((e) => e.key)
            .toList();
        if (teamUids.length > 1) {
          teamId = _chatService.getCanonicalId(teamUids);
        }
      }
    }

    final ids = [gpId];
    if (teamId != null && teamId != gpId) {
      ids.add(teamId);
    }

    debugPrint('🔍 Chat: Stream Refresh Listen: $ids');

    // Ensure & Listen
    _ensureAndListen(ids, allUids, myUid);
  }

  void _handleNewMessages(List<ActivityItem> messages) {
    if (!mounted) return;

    final newMsgs =
        messages.where((m) => !_processedMsgIds.contains(m.id)).toList();
    if (newMsgs.isEmpty) return;

    for (final msg in newMsgs) {
      _processedMsgIds.add(msg.id);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Filter recent & relevant
    final recentMsgs = newMsgs.where((m) {
      if ((now - m.timestamp) >= 10000) return false;
      if (m.isTeam) {
        if (m.senderId == myUid) return true;
        final senderData = widget.players[m.senderId];
        final myData = widget.players[myUid];
        if (senderData == null || myData == null) return false;
        return senderData['team'] == myData['team'];
      }
      return true;
    }).toList();

    // Sort by time so we process latest last (though stream usually sorted)
    recentMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final msg in recentMsgs) {
      _addChatEffect(msg);
    }
  }

  void _addChatEffect(ActivityItem msg) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = msg.senderId == myUid;

    // 1. Update Active Bubble (Latest wins)
    // If text is purely emojis/very short, we might skip bubble?
    // User requested "text+emoji" as bubble.
    // We will show bubble for everything.

    setState(() {
      _activeBubbles[msg.senderId] = msg;
    });

    // Reset Timer
    _bubbleTimers[msg.senderId]?.cancel();
    _bubbleTimers[msg.senderId] = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          // Only remove if it's still THIS message (check timestamp/id)
          if (_activeBubbles[msg.senderId]?.id == msg.id) {
            _activeBubbles.remove(msg.senderId);
          }
        });
      }
    });

    // 2. Flying Emojis (Visual Flair only for very short emoji-like text)
    // Only if it looks like just emojis (heuristic len <= 4)
    final bool shouldFly = msg.text.runes.length <= 4;
    if (shouldFly) {
      _triggerFlyingEmoji(msg, isMe);
    }
  }

  void _triggerFlyingEmoji(ActivityItem msg, bool isMe) {
    // ... Calculate start pos based on visual seat ...
    // Re-using simplified logic for flying start
    // (Ideally share with bubble pos, but flying is fire-and-forget)

    // We'll calculate start pos same as bubble for consistency
    final bubblePos = _calculateBubblePosition(msg.senderId);
    if (bubblePos == null) return;

    final size = MediaQuery.of(context).size;
    final flyTargetPos = Offset(size.width / 2 - 24, size.height / 2 - 24);

    Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final flyId = 'fly_${msg.timestamp}';
      setState(() {
        _flyingEmojis.add({
          'id': flyId,
          'widget': FlyingBubble(
            key: ValueKey(flyId),
            text: msg.text,
            isMe: isMe,
            startPos: bubblePos,
            targetPos: flyTargetPos,
            onComplete: () {
              if (mounted) {
                setState(() {
                  _flyingEmojis.removeWhere((e) => e['id'] == flyId);
                });
              }
            },
          )
        });
      });
    });
  }

  // Calculate Bubble Anchor Position AND Tail Alignment
  // Returns Offset of the bubble's "Tail Tip" (which touches/points to avatar)
  Offset? _calculateBubblePosition(String senderId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = senderId == myUid;
    int visualIndex = 0;

    if (isMe) {
      visualIndex = 0;
    } else {
      int senderSeat = -1;
      int mySeat = widget.localPlayerIndex;
      // Ensure local player index is valid
      if (mySeat < 0) mySeat = 0;

      if (widget.players.containsKey(senderId)) {
        final pData = widget.players[senderId];
        if (pData is Map && pData.containsKey('seat')) {
          senderSeat = int.tryParse(pData['seat'].toString()) ?? -1;
        }
      }

      if (senderSeat != -1) {
        visualIndex = (senderSeat - mySeat + 4) % 4;
      } else {
        return null;
      }
    }

    final size = MediaQuery.of(context).size;
    final boardTop = widget.boardRect.top;
    final boardSize = widget.boardRect.width;

    // Avatar layout constants from GameScreen
    final avatarSize = 44.0;
    final padding = 8.0; // Space between avatar and bubble

    // Visual Avatars Coords (Top-Left point of Avatar Image):
    // BL (0): Left 16, Top boardTop + boardSize + 32
    // TL (1): Left 16, Top boardTop - 64
    // TR (2): Right 16 (=> Left = W - 16 - 44), Top boardTop - 64
    // BR (3): Right 16 (=> Left = W - 16 - 44), Top boardTop + boardSize + 32

    final leftColX = 16.0;
    final rightColX = size.width - 16.0 - avatarSize;
    final topRowY = boardTop - 64;
    final bottomRowY = boardTop + boardSize + 32;

    switch (visualIndex) {
      case 0: // BL (Me) -> Bubble BELOW Avatar
        // Visual: Avatar is at (leftColX, bottomRowY).
        // Anchor: Bottom-Left of Avatar + Padding Down.
        // Bubble Alignment: TopLeft (Starts at Anchor, grows Down & Right).
        return Offset(leftColX, bottomRowY + avatarSize + padding);

      case 1: // TL -> Bubble ABOVE Avatar
        // Visual: Avatar is at (leftColX, topRowY).
        // Anchor: Top-Left of Avatar - Padding Up.
        // Bubble Alignment: BottomLeft (Ends at Anchor, grew Up & Right).
        return Offset(leftColX, topRowY - padding);

      case 2: // TR -> Bubble ABOVE Avatar
        // Visual: Avatar is at (rightColX, topRowY).
        // Anchor: Top-Right of Avatar - Padding Up.
        // Bubble Alignment: BottomRight (Ends at Anchor, grew Up & Left).
        return Offset(rightColX + avatarSize, topRowY - padding);

      case 3: // BR -> Bubble BELOW Avatar
        // Visual: Avatar is at (rightColX, bottomRowY).
        // Anchor: Bottom-Right of Avatar + Padding Down.
        // Bubble Alignment: TopRight (Starts at Anchor, grows Down & Left).
        return Offset(
            rightColX + avatarSize, bottomRowY + avatarSize + padding);

      default:
        return Offset(size.width / 2, size.height / 2);
    }
  }

  // Get alignment for the Bubble (where is the tail?)
  Alignment _getBubbleAlignment(String senderId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = senderId == myUid;
    int visualIndex = 0;

    if (!isMe) {
      int senderSeat = -1;
      int mySeat = widget.localPlayerIndex;
      if (mySeat < 0) mySeat = 0;

      if (widget.players.containsKey(senderId)) {
        final pData = widget.players[senderId];
        if (pData is Map && pData.containsKey('seat')) {
          senderSeat = int.tryParse(pData['seat'].toString()) ?? -1;
        }
      }
      if (senderSeat != -1) {
        visualIndex = (senderSeat - mySeat + 4) % 4;
      }
    }

    switch (visualIndex) {
      case 0: // BL -> Bubble Below -> Tail at TopLeft
        return Alignment.topLeft;
      case 1: // TL -> Bubble Above -> Tail at BottomLeft
        return Alignment.bottomLeft;
      case 2: // TR -> Bubble Above -> Tail at BottomRight
        return Alignment.bottomRight;
      case 3: // BR -> Bubble Below -> Tail at TopRight
        return Alignment.topRight;
      default:
        return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static Bubbles (Single per user)
        ..._activeBubbles.entries.map((entry) {
          final uid = entry.key;
          final msg = entry.value;
          final pos = _calculateBubblePosition(uid);
          final align = _getBubbleAlignment(uid);

          if (pos == null) return const SizedBox.shrink();

          return AnimatedChatBubble(
            key: ValueKey(msg.id), // New ID = Rebuild = Animation
            text: msg.text,
            isMe: uid == (FirebaseAuth.instance.currentUser?.uid),
            isTeam: msg.isTeam,
            anchor: pos,
            tailAlignment: align,
          );
        }),

        // Flying Emojis
        ..._flyingEmojis.map((e) => e['widget'] as Widget),
      ],
    );
  }
}

class AnimatedChatBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final bool isTeam;
  final Offset anchor;
  final Alignment
      tailAlignment; // The corner of the bubble that touches the anchor

  const AnimatedChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.isTeam,
    required this.anchor,
    required this.tailAlignment,
  });

  @override
  State<AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine offset based on Alignment to make 'anchor' the tip
    // If Alignment is BottomLeft, bubble is drawn Top-Right of anchor.
    // Wait, simpler: Use FractionalTranslation or just basic alignment math is hard without size.
    // Easier: Positioned widget with constraints.

    // We want the 'tailAlignment' corner of the bubble to be at 'widget.anchor'.
    // e.g. tail=BottomLeft -> wrap in Align(bottomLeft) and Positioned(left: anchor.dx, bottom: ...)?
    // No, screen coords.

    // Let's deduce Positioned arguments.
    double? left, top, right, bottom;

    // Safety check for screen bounds could be added, but assuming safe area.

    if (widget.tailAlignment == Alignment.bottomLeft) {
      // Tail is BL. Anchor is at BL corner of bubble.
      // Bubble extends Up and Right.
      left = widget.anchor.dx;
      bottom = MediaQuery.of(context).size.height - widget.anchor.dy;
    } else if (widget.tailAlignment == Alignment.topLeft) {
      // Tail is TL. Anchor is at TL corner of bubble.
      // Bubble extends Down and Right.
      left = widget.anchor.dx;
      top = widget.anchor.dy;
    } else if (widget.tailAlignment == Alignment.topRight) {
      // Tail is TR. Anchor is at TR corner of bubble.
      // Bubble extends Down and Left.
      // Positioned uses Right relative to screen width.
      // anchor.dx is absolute X. ScreenW - anchor.dx is Right inset.
      right = MediaQuery.of(context).size.width - widget.anchor.dx;
      top = widget.anchor.dy;
    } else if (widget.tailAlignment == Alignment.bottomRight) {
      // Tail is BR. Anchor is at BR.
      // Bubble extends Up and Left.
      right = MediaQuery.of(context).size.width - widget.anchor.dx;
      bottom = MediaQuery.of(context).size.height - widget.anchor.dy;
    }

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: ScaleTransition(
        scale: _scaleAnim,
        alignment: widget.tailAlignment, // Scale from the tail
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color:
                  widget.isTeam ? Colors.black.withOpacity(0.9) : Colors.white,
              border: widget.isTeam
                  ? Border.all(color: const Color(0xFFC0C0C0), width: 1.5)
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                    widget.tailAlignment == Alignment.topLeft ? 0 : 16),
                topRight: Radius.circular(
                    widget.tailAlignment == Alignment.topRight ? 0 : 16),
                bottomLeft: Radius.circular(
                    widget.tailAlignment == Alignment.bottomLeft ? 0 : 16),
                bottomRight: Radius.circular(
                    widget.tailAlignment == Alignment.bottomRight ? 0 : 16),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                    color:
                        widget.isTeam ? const Color(0xFFC0C0C0) : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              )
            ],
          ),
        ),
      ),
    );
  }
}
