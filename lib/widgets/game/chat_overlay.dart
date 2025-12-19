import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_model.dart';
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
  final ChatService _chatService = ChatService();
  StreamSubscription? _chatSub;

  // Track active widgets
  final List<Map<String, dynamic>> _staticBubbles = [];
  final List<Map<String, dynamic>> _flyingEmojis = [];
  final Set<String> _processedMsgIds = {};

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔍 Chat: Overlay Init | GameID: ${widget.gameId} | LocalPlayer: ${widget.localPlayerIndex}');
    _chatSub = _chatService.getGameChat(widget.gameId).listen((messages) {
      if (messages.isEmpty) return;
      _handleNewMessages(messages);
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  void _handleNewMessages(List<ChatMessage> messages) {
    if (!mounted) return;

    // Filter out already processed messages
    final newMsgs =
        messages.where((m) => !_processedMsgIds.contains(m.id)).toList();
    if (newMsgs.isEmpty) return;

    // Mark as processed
    for (final msg in newMsgs) {
      _processedMsgIds.add(msg.id);
    }

    // Only animate if they are relatively recent (e.g. within last 10 seconds)
    final now = DateTime.now().millisecondsSinceEpoch;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final recentMsgs = newMsgs.where((m) {
      if ((now - m.timestamp) >= 10000) return false;

      // Privacy Check
      if (m.isTeam) {
        if (m.senderId == myUid) return true;
        final senderData = widget.players[m.senderId];
        final myData = widget.players[myUid];
        if (senderData == null || myData == null) return false;
        return senderData['team'] == myData['team'];
      }
      return true;
    }).toList();

    for (final msg in recentMsgs) {
      debugPrint(
          '🔍 Chat: Overlay Effect | MsgID: ${msg.id} | Sender: ${msg.senderId} | Text: ${msg.text}');
      _addChatEffect(msg);
    }
  }

  void _addChatEffect(ChatMessage msg) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMe = msg.senderId == myUid;

    // Calculate visual position index (0=Bottom/Me, 1=Left, 2=Top, 3=Right)
    int visualIndex = 0;

    if (isMe) {
      visualIndex = 0;
    } else {
      // Find sender's seat
      int senderSeat = -1;
      int mySeat = widget.localPlayerIndex;

      // Ensure local player index is valid
      if (mySeat < 0) mySeat = 0;

      if (widget.players.containsKey(msg.senderId)) {
        final pData = widget.players[msg.senderId];
        if (pData is Map && pData.containsKey('seat')) {
          senderSeat = pData['seat'] as int;
        }
      }

      if (senderSeat != -1) {
        // Calculate relative visual position
        // 0=Bottom, 1=Left, 2=Top, 3=Right (Clockwise)
        visualIndex = (senderSeat - mySeat + 4) % 4;
      } else {
        visualIndex = 2; // Default to top/opponent
      }
    }

    final size = MediaQuery.of(context).size;

    // Use board rect for precise positioning
    final boardTop = widget.boardRect.top;
    final boardSize = widget.boardRect.width; // Assuming square

    // Define positions based on Visual Index
    Offset bubblePos;

    // Precise positioning relative to Avatars (from GameScreen logic)
    // Avatar is at:
    // BL (0): Left 16, Top boardTop + boardSize + 32
    // TL (1): Left 16, Top boardTop - 64
    // TR (2): Right 16, Top boardTop - 64
    // BR (3): Right 16, Top boardTop + boardSize + 32
    // Avatar width approx 60px.

    final avatarLeft = 16.0;
    final avatarRight = size.width - 16.0;
    final avatarBottomTop = boardTop + boardSize + 32;
    final avatarTopTop = boardTop - 64;

    switch (visualIndex) {
      case 0: // Me (Bottom Left) -> Bubble to RIGHT of Avatar
        // Avatar is at (16, avatarBottomTop)
        // Bubble should be at (16 + 60 + 10, avatarBottomTop)
        bubblePos = Offset(avatarLeft + 60 + 8, avatarBottomTop);
        break;
      case 1: // Top Left -> Bubble to RIGHT of Avatar
        // Avatar is at (16, avatarTopTop)
        bubblePos = Offset(avatarLeft + 60 + 8, avatarTopTop);
        break;
      case 2: // Top Right -> Bubble to LEFT of Avatar
        // Avatar Right edge is at avatarRight
        // Bubble Right edge should be at (avatarRight - 60 - 8)
        // Since Positioned uses left/top usually, we calculate Left.
        // But for static bubble we set right/left properties.
        // Let's just set the anchor point here and handle alignment in Positioned.
        bubblePos = Offset(avatarRight - 60 - 8, avatarTopTop);
        break;
      case 3: // Bottom Right -> Bubble to LEFT of Avatar
        bubblePos = Offset(avatarRight - 60 - 8, avatarBottomTop);
        break;
      default:
        bubblePos = Offset(avatarLeft + 60 + 8, avatarBottomTop);
    }

    final flyStartPos = bubblePos;
    final flyTargetPos = Offset(size.width / 2 - 24, size.height / 2 - 24);

    // 1. Add Static Bubble
    final String bubbleId = 'bubble_${msg.timestamp}';
    setState(() {
      _staticBubbles.add({
        'id': bubbleId,
        'widget': Positioned(
          // If Visual Index is 0 (BL) or 1 (TL), Align Left (Bubble starts at bubblePos.dx)
          // If Visual Index is 2 (TR) or 3 (BR), Align Right (Bubble ends at bubblePos.dx)
          left: (visualIndex == 0 || visualIndex == 1) ? bubblePos.dx : null,
          right: (visualIndex == 2 || visualIndex == 3)
              ? size.width - bubblePos.dx // Distance from right edge
              : null,
          top: bubblePos.dy,
          child:
              StaticChatBubble(text: msg.text, isMe: isMe, isTeam: msg.isTeam),
        )
      });
    });

    // Remove Static Bubble after 10 seconds (Turn Time)
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _staticBubbles.removeWhere((e) => e['id'] == bubbleId);
        });
      }
    });

    // 2. Check for Emoji to Fly
    // Heuristic: Length <= 4 (e.g. 1-2 emojis)
    final bool shouldFly = msg.text.runes.length <= 4;

    if (shouldFly) {
      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        final flyId = 'fly_${msg.timestamp}';
        setState(() {
          _flyingEmojis.add({
            'id': flyId,
            'widget': FlyingBubble(
              key: ValueKey(flyId),
              text: msg.text,
              isMe: isMe,
              startPos: flyStartPos,
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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static Bubbles
        ..._staticBubbles.map((e) => e['widget'] as Widget),

        // Flying Emojis
        ..._flyingEmojis.map((e) => e['widget'] as Widget),
      ],
    );
  }
}

class StaticChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isTeam;

  const StaticChatBubble(
      {super.key, required this.text, required this.isMe, this.isTeam = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 160),
      decoration: BoxDecoration(
        color: isTeam ? Colors.black.withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isMe ? Radius.zero : const Radius.circular(16),
          bottomRight: isMe ? const Radius.circular(16) : Radius.zero,
        ),
        border: isTeam
            ? Border.all(color: const Color(0xFFC0C0C0), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isTeam
                ? const Color(0xFFC0C0C0).withOpacity(0.5)
                : Colors.black.withOpacity(0.2),
            blurRadius: isTeam ? 12 : 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isTeam ? const Color(0xFFC0C0C0) : Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
