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

    switch (visualIndex) {
      case 0: // Me (Bottom Left/Center)
        bubblePos = Offset(60, boardTop + boardSize + 20);
        break;
      case 1: // Left Player
        bubblePos = Offset(40, boardTop + 100);
        break;
      case 2: // Top Player (Opponent)
        bubblePos = Offset(size.width - 120, boardTop - 50);
        break;
      case 3: // Right Player
        bubblePos = Offset(size.width - 60, boardTop + 200);
        break;
      default:
        bubblePos = Offset(60, boardTop + boardSize + 20);
    }

    final flyStartPos = bubblePos;
    final flyTargetPos = Offset(size.width / 2 - 24, size.height / 2 - 24);

    // 1. Add Static Bubble
    final String bubbleId = 'bubble_${msg.timestamp}';
    setState(() {
      _staticBubbles.add({
        'id': bubbleId,
        'widget': Positioned(
          left: bubblePos.dx < size.width / 2 ? bubblePos.dx : null,
          right: bubblePos.dx >= size.width / 2
              ? size.width - bubblePos.dx - 120
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
