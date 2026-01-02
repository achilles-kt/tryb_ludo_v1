import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/contact_service.dart';
import 'conversation_screen.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../services/social_service.dart';
import '../services/user_profile_service.dart';
import '../services/presence_service.dart';
import '../widgets/modals/phone_verification_modal.dart';
import '../widgets/modals/profile_edit_modal.dart';

// New UI Components
import '../widgets/social/social_header.dart';
import '../widgets/social/sync_card_v2.dart';
import '../widgets/social/friend_suggestion_card.dart';
import '../widgets/social/friend_tile.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final SocialService _socialService = SocialService.instance;
  final ActivityService _chatService = ActivityService();

  Stream<List<UserModel>>? _friendsStream;
  Stream<List<UserModel>>? _recentsStream;
  Stream<bool>? _syncedStream;

  @override
  void initState() {
    super.initState();
    _friendsStream = _socialService.getFriends();
    _recentsStream = _socialService.getRecentPlayers();
    _syncedStream = _socialService.getContactsSyncedStream();
  }

  Future<void> _handleSync(BuildContext context) async {
    final phoneData = await UserProfileService.instance.fetchLinkedPhone();
    final isVerified = phoneData != null &&
        phoneData['verified'] == true &&
        (phoneData['number'] as String?)?.isNotEmpty == true;

    if (isVerified) {
      final permitted = await ContactService.instance.requestPermission();
      if (permitted) {
        await ContactService.instance.syncContacts();
      }
    } else {
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PhoneVerificationModal(
            onSuccess: () {
              if (context.mounted) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const ProfileEditModal(),
                );
              }
            },
          ),
        );
      }
    }
  }

  void _showContactSyncModal(BuildContext context) {
    _handleSync(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header
            SocialHeader(
              onAddFriend: () => _showContactSyncModal(context),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Sync Card (Conditional)
                    StreamBuilder<bool>(
                        stream: _syncedStream,
                        initialData: false,
                        builder: (context, snapshot) {
                          final isSynced = snapshot.data == true;
                          if (isSynced) return const SizedBox.shrink();

                          return SyncCardV2(
                            onSync: () => _handleSync(context),
                          );
                        }),

                    // 3. Friend Suggestions (Horizontal)
                    StreamBuilder<List<UserModel>>(
                        stream: _recentsStream,
                        builder: (context, snapshot) {
                          final players = snapshot.data ?? [];
                          if (players.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Text(
                                  "FRIEND SUGGESTIONS",
                                  style: AppTheme.label
                                      .copyWith(fontSize: 11, letterSpacing: 1),
                                ),
                              ),
                              SizedBox(
                                height: 180, // Height for suggestion cards
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 8, bottom: 20),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: players.length,
                                  itemBuilder: (ctx, i) {
                                    final p = players[i];
                                    String contextText = "Played Recently";
                                    bool showActions = true;

                                    if (p.friendStatus == 'pending') {
                                      contextText = "Request Received";
                                    } else if (p.friendStatus == 'requested') {
                                      contextText = "Request Sent";
                                      showActions =
                                          false; // Hide buttons if sent
                                    }

                                    return FriendSuggestionCard(
                                      name: p.name,
                                      avatarUrl: p.avatar.isNotEmpty
                                          ? p.avatar
                                          : 'assets/avatars/a1.png',
                                      contextText: contextText,
                                      showActions: showActions,
                                      onAccept: () {
                                        if (p.friendStatus == 'pending') {
                                          _socialService
                                              .respondToFriendRequest(
                                                  p.id, 'accept')
                                              .then((_) => ScaffoldMessenger.of(
                                                      context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Friend Request Accepted!"))));
                                        } else {
                                          _socialService
                                              .sendFriendRequest(p.id)
                                              .then((_) => ScaffoldMessenger.of(
                                                      context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Request Sent!"))));
                                        }
                                      },
                                      onDeny: () {
                                        if (p.friendStatus == 'pending') {
                                          _socialService.respondToFriendRequest(
                                              p.id, 'reject');
                                        }
                                        // TODO: Implement Hide Suggestion for non-pending
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),

                    // 4. Friends List Label
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: StreamBuilder<List<UserModel>>(
                          stream: _friendsStream,
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length ?? 0;
                            return Text("FRIENDS ($count)",
                                style: AppTheme.label
                                    .copyWith(fontSize: 11, letterSpacing: 1));
                          }),
                    ),

                    // 5. Friends List (Vertical)
                    StreamBuilder<List<UserModel>>(
                        stream: _friendsStream,
                        builder: (context, snapshot) {
                          final friends = snapshot.data ?? [];
                          if (friends.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: Center(
                                child: Text("No friends yet.",
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3))),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: friends.length,
                            padding: const EdgeInsets.only(
                                bottom: 100), // Space for nav bar
                            itemBuilder: (ctx, i) {
                              final f = friends[i];

                              return StreamBuilder<Map<String, dynamic>>(
                                  stream: PresenceService().getUserStatus(f.id),
                                  initialData: {'state': 'offline'},
                                  builder: (context, snap) {
                                    final pData = snap.data ?? {};
                                    final state = pData['state'] ?? 'offline';
                                    final lastSeen = pData[
                                        'last_seen']; // Optional timestamp logic

                                    FriendStatus status = FriendStatus.offline;
                                    String statusText = "Offline";

                                    if (state == 'online') {
                                      status = FriendStatus.online;
                                      statusText = "Online";
                                    } else if (state == 'playing') {
                                      status = FriendStatus.playing;
                                      statusText =
                                          "Playing 2P..."; // Could enrich if we knew game mode
                                    } else {
                                      // Offline
                                      statusText =
                                          "Offline"; // Could add "• 2h ago" if we parsed timestamp
                                    }

                                    return FriendTile(
                                      name: f.name,
                                      avatarUrl: f.avatar.isNotEmpty
                                          ? f.avatar
                                          : 'assets/avatars/a1.png',
                                      status: status,
                                      statusText: statusText,
                                      onTap: () {
                                        // Open Chat or Profile
                                        _openChat(f);
                                      },
                                      onChat: () => _openChat(f),
                                    );
                                  });
                            },
                          );
                        })
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(UserModel f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
            peerId: f.id, peerName: f.name, peerAvatar: f.avatar),
      ),
    );
  }
}
