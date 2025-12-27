import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../models/activity_item.dart';
import '../widgets/activity_item_renderer.dart';
import '../widgets/chat_input_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ConversationScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerAvatar;

  const ConversationScreen({
    Key? key,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
  }) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ActivityService _activityService = ActivityService.instance;

  Stream<List<ActivityItem>>? _activityStream;
  Stream<bool>? _typingStream;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _activityStream = _activityService.getDirectChat(widget.peerId);
    _typingStream = _activityService.getTypingStatus(widget.peerId);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_textController.text.isNotEmpty) {
      _activityService.setTypingStatus(widget.peerId, true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _activityService.setTypingStatus(widget.peerId, false);
      });
    } else {
      _activityService.setTypingStatus(widget.peerId, false);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _activityService.setTypingStatus(widget.peerId, false);
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _typingTimer?.cancel();
    _activityService.setTypingStatus(widget.peerId, false);
    _activityService.sendDirectMessage(toUid: widget.peerId, message: text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
              child: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF0F1218), Color(0xFF1A1D24)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
          )),

          Column(
            children: [
              // 1. Custom App Bar
              _buildAppBar(context),

              // 2. Presence Sticky Header (If Playing)
              _buildPresenceStickyHeader(),

              const Divider(color: Colors.white10, height: 1),

              // 3. Activity List
              Expanded(
                child: StreamBuilder<List<ActivityItem>>(
                    stream: _activityStream,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];

                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isMe = item.senderId ==
                              (FirebaseAuth.instance.currentUser?.uid);
                          return ActivityItemRenderer(item: item, isMe: isMe);
                        },
                      );
                    }),
              ),

              // 4. Input Area
              _buildInputArea(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              backgroundImage: widget.peerAvatar.isNotEmpty
                  ? (widget.peerAvatar.startsWith('http')
                      ? NetworkImage(widget.peerAvatar)
                      : AssetImage(widget.peerAvatar) as ImageProvider)
                  : const AssetImage('assets/avatars/a1.png'),
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peerName,
                      style: AppTheme.text
                          .copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                  StreamBuilder<bool>(
                      stream: _typingStream,
                      builder: (context, typingSnap) {
                        if (typingSnap.data == true) {
                          return Text("Typing...",
                              style: AppTheme.label
                                  .copyWith(color: AppTheme.neonBlue));
                        }
                        // Default status from presence if not typing
                        return StreamBuilder<Map<String, dynamic>>(
                            stream:
                                PresenceService().getUserStatus(widget.peerId),
                            initialData: {'state': 'offline'},
                            builder: (context, presenceSnap) {
                              final state =
                                  presenceSnap.data?['state'] ?? 'offline';
                              return Text(
                                state == 'offline'
                                    ? 'Offline'
                                    : (state == 'playing'
                                        ? 'Playing Ludo'
                                        : 'Online'),
                                style: AppTheme.label.copyWith(
                                    color: state == 'online'
                                        ? AppTheme.neonGreen
                                        : (state == 'playing'
                                            ? AppTheme.gold
                                            : Colors.white30)),
                              );
                            });
                      }),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onPressed: () {},
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceStickyHeader() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: PresenceService().getUserStatus(widget.peerId),
      builder: (context, snapshot) {
        final state = snapshot.data?['state'];
        if (state != 'playing') return const SizedBox.shrink();

        // Sticky Header for Game
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: AppTheme.gold.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gamepad, size: 16, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text("Playing Ludo Now",
                  style: AppTheme.label.copyWith(color: AppTheme.gold)),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  // Spectate logic / Invite
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.gold),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text("Spectate",
                      style: AppTheme.label
                          .copyWith(color: AppTheme.gold, fontSize: 10)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    // We wrap in SafeArea for bottom padding
    return SafeArea(
      top: false,
      child: ChatInputBar(
        controller: _textController,
        onSend: _sendMessage,
        // We handle typing status via listener on controller in initState,
        // but we can also hook into onChanged here if we wanted to refactor that logic.
        // For now, keeping existing logic attached to controller.
      ),
    );
  }
}
