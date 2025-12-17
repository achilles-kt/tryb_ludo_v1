// lib/widgets/chat_sheet.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';

class ChatSheet extends StatefulWidget {
  final String? gameId; // If null, assume Global Chat
  final bool initialIsTeamChat;
  final bool showTeamToggle;
  final Map<String, dynamic>? players;

  const ChatSheet({
    Key? key,
    this.gameId,
    this.initialIsTeamChat = false,
    this.showTeamToggle = true,
    this.players,
  }) : super(key: key);

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late Stream<List<ChatMessage>> _chatStream;
  late bool _isTeamChat;

  @override
  void initState() {
    super.initState();
    _isTeamChat = widget.initialIsTeamChat;
    if (widget.gameId != null) {
      _chatStream = _chatService.getGameChat(widget.gameId!);
    } else {
      _chatStream = _chatService.getGlobalChat();
    }
    debugPrint(
        '🔍 Chat: Opening Widget | User: $_uid | Type: ${widget.gameId == null ? "Global" : "Game"} | GameID: ${widget.gameId}');
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Clear immediately for UX
    _controller.clear();

    debugPrint(
        '🔍 Chat: Typed/Sending | User: $_uid | Msg: $text | Type: ${widget.gameId == null ? "Global" : "Game"}');

    if (widget.gameId != null) {
      _chatService.sendGameMessage(widget.gameId!, text, isTeam: _isTeamChat);
    } else {
      _chatService.sendGlobalMessage(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard awareness
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75, // Fixed 75% height
      decoration: const BoxDecoration(
          color: Color(0xFF14161b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            // Header
            Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.gameId == null
                                  ? 'High Rollers Club'
                                  : 'Game Chat',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white),
                            ),
                            if (widget.gameId == null)
                              const Text(
                                'Global Chat • Persistent',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white54),
                              ),
                          ],
                        ),
                      ),
                      if (widget.gameId != null && widget.showTeamToggle)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _toggleBtn('All', !_isTeamChat),
                              _toggleBtn('Team', _isTeamChat),
                            ],
                          ),
                        ),
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop())
                    ])),

            // Messages List
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(
                        child: Text("No messages yet.",
                            style: TextStyle(color: Colors.white30)));
                  }

                  // Filter logic for Team Chat privacy
                  final visibleMessages = messages.where((msg) {
                    if (!msg.isTeam)
                      return true; // Global/All messages always visible
                    if (msg.senderId == _uid)
                      return true; // My messages always visible

                    // If game data missing, hide team messages from others to be safe
                    if (widget.players == null) return false;

                    final senderData = widget.players![msg.senderId];
                    final myData = widget.players![_uid];

                    if (senderData == null || myData == null) return false;

                    final senderTeam = senderData['team'];
                    final myTeam = myData['team'];

                    // Only show if on same team
                    return senderTeam != null && senderTeam == myTeam;
                  }).toList();

                  // Messages are sorted OLD ... NEW by service
                  // ListView standard: Top is index 0.
                  // We want Newest at bottom.
                  // So index 0 = OLD. Index N = NEW.
                  // Standard ListView works.
                  // To auto-scroll to bottom, we usually use reverse: true and sort New...Old.
                  // Let's locally reverse to New...Old and use reverse: true.
                  final visualMessages = visibleMessages.reversed.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: visualMessages.length,
                    itemBuilder: (ctx, i) {
                      final msg = visualMessages[i];
                      return _msgRow(msg);
                    },
                  );
                },
              ),
            ),

            // Input Area
            Padding(
                padding: const EdgeInsets.only(
                    left: 12, right: 12, top: 12, bottom: 20),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(30)),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.white30)),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                      backgroundColor:
                          const Color(0xFF6366f1), // Approximate primary
                      radius: 22,
                      child: IconButton(
                          icon: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                          onPressed: _sendMessage))
                ]))
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) setState(() => _isTeamChat = !_isTeamChat);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (_isTeamChat
                  ? const Color(0xFFC0C0C0)
                  : const Color(0xFF6366f1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive
                ? (_isTeamChat ? Colors.black : Colors.white)
                : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _msgRow(ChatMessage msg) {
    final isMe = msg.senderId == _uid;
    // Fallback avatar
    final avatar = 'assets/avatars/a${(msg.senderId.hashCode % 5) + 1}.png';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(radius: 14, backgroundImage: AssetImage(avatar)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? (msg.isTeam
                          ? const Color(0xFFC0C0C0).withOpacity(0.8)
                          : const Color(0xFF6366f1))
                      : (msg.isTeam
                          ? const Color(0xFFC0C0C0).withOpacity(0.2)
                          : Colors.white12),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                  border: msg.isTeam
                      ? Border.all(color: const Color(0xFFC0C0C0), width: 1)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && msg.senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(msg.senderName!,
                            style: TextStyle(
                                fontSize: 10,
                                color: msg.isTeam && !isMe
                                    ? const Color(0xFFC0C0C0)
                                    : Colors.white54)),
                      ),
                    Text(msg.text,
                        style: TextStyle(
                            color: msg.isTeam && isMe
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ),
          ]),
    );
  }
}
