import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import '../../models/activity_item.dart';
import '../../widgets/activity_item_renderer.dart';
import 'chat_input_bar.dart';

class ChatSheet extends StatefulWidget {
  final String? gameId; // If null, assume Global Chat
  final bool initialIsTeamChat;
  final bool showTeamToggle;
  final Map<String, dynamic>? players;

  const ChatSheet({
    super.key,
    this.gameId,
    this.initialIsTeamChat = false,
    this.showTeamToggle = true,
    this.players,
  });

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ActivityService _chatService = ActivityService.instance;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late Stream<List<ActivityItem>> _chatStream;
  late bool _isTeamChat;

  @override
  void initState() {
    super.initState();
    _isTeamChat = widget.initialIsTeamChat;
    _updateStream();
  }

  void _updateStream() {
    if (widget.gameId != null) {
      final cid = _currentConvId;
      if (cid != null) {
        debugPrint('ChatSheet: Listening to $cid');
        _chatStream = _chatService.getConversationStream(cid);
      } else {
        _chatStream = const Stream.empty();
      }
    } else {
      _chatStream = _chatService.getGlobalChat();
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    if (widget.gameId != null) {
      // Phase 14: Unified Stream Logic
      if (widget.players == null) return;

      final convId = _currentConvId;

      if (convId != null) {
        debugPrint("Sending ${_isTeamChat ? 'Team' : 'All'} msg to $convId");

        _chatService.sendMessageToConversation(
            convId: convId,
            text: text,
            type: 'text',
            context: {'gameId': widget.gameId, 'isTeam': _isTeamChat});
      }
    } else {
      _chatService.sendGlobalMessage(text);
    }
  }

  Timer? _typingDebounce;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Helper to get current active conversation ID
  String? get _currentConvId {
    if (widget.gameId == null) {
      return null; // Global Chat doesn't support typing yet (or hardcode global_chat)
    }

    if (widget.players == null) return null;

    final ids =
        _chatService.getGameConversationIds(widget.gameId!, widget.players!);

    if (_isTeamChat) {
      // Team Chat is the second ID if it exists (and is distinct)
      // getGameConversationIds returns [Group, Team] or [Group]
      if (ids.length > 1) {
        return ids[1];
      }
      // If we are in "Team" mode but no team chat exists (e.g. 2p game),
      // typically we shouldn't be here (toggle hidden).
      // Fallback to Group? Or Null?
      return null;
    } else {
      // Group Chat is always first
      if (ids.isNotEmpty) {
        return ids[0];
      }
    }

    return null;
  }

  void _onTextChanged(String value) {
    final cid = _currentConvId;
    if (cid == null) return;

    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    _chatService.setTypingStatusForConversation(cid, true);

    _typingDebounce = Timer(const Duration(milliseconds: 2000), () {
      _chatService.setTypingStatusForConversation(cid, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
          // Unified Gradient Background
          gradient: LinearGradient(
              colors: [Color(0xFF0F1218), Color(0xFF1A1D24)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
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
                            // Typing Indicator
                            if (widget.gameId != null && _currentConvId != null)
                              StreamBuilder<bool>(
                                stream:
                                    _chatService.getTypingStatusForConversation(
                                        _currentConvId!),
                                builder: (context, snap) {
                                  if (snap.data == true) {
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        "Someone is typing...",
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 10,
                                            color: Colors.greenAccent),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              )
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
              child: StreamBuilder<List<ActivityItem>>(
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
                    if (!msg.isTeam) return true;
                    if (msg.senderId == _uid) return true;

                    if (widget.players == null) return false;

                    final senderData = widget.players![msg.senderId];
                    final myData = widget.players![_uid];

                    if (senderData == null || myData == null) return false;

                    final senderTeam = senderData['team'];
                    final myTeam = myData['team'];

                    return senderTeam != null && senderTeam == myTeam;
                  }).toList();

                  final visualMessages = visibleMessages;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: visualMessages.length,
                    itemBuilder: (ctx, i) {
                      final item = visualMessages[i];
                      final isMe = item.senderId == _uid;
                      return ActivityItemRenderer(item: item, isMe: isMe);
                    },
                  );
                },
              ),
            ),

            // Unified Input Area
            ChatInputBar(
              controller: _controller,
              onSend: _sendMessage,
              onChanged: _onTextChanged,
              hintText: 'Type a message...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() {
            _isTeamChat = !_isTeamChat;
            _controller.clear();
            _updateStream();
          });
        }
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
}
