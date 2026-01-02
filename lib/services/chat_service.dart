import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/activity_item.dart';

// ActivityItem is now a proper model in ../models/activity_item.dart

class ActivityService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton Support
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();
  static ActivityService get instance => _instance;

  // ... Streams are already using ActivityItem from previous edit ... (Assuming previous edit applied to methods, but imports were missing)
  // Re-verify streams if needed, but this chunk targets imports and sendGameMessage

  // Unified Messaging: Send to specific Conversation ID
  Future<void> sendMessageToConversation({
    required String convId,
    required String text,
    String type = 'text',
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> context = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await FirebaseFunctions.instance.httpsCallable('sendMessage').call({
        'convId': convId,
        'text': text,
        'type': type,
        'payload': payload,
        'context': context
      });
    } catch (e) {
      if (e.toString().contains('not-found')) {
        debugPrint("Conversation not found. Attempting to create: $convId");
        try {
          await _createConversationForId(convId);

          // Retry Send
          await FirebaseFunctions.instance.httpsCallable('sendMessage').call({
            'convId': convId,
            'text': text,
            'type': type,
            'payload': payload,
            'context': context
          });
          return;
        } catch (retryErr) {
          debugPrint("Error creating/retrying conversation: $retryErr");
          rethrow;
        }
      }
      debugPrint("Error sending unified message: $e");
      rethrow;
    }
  }

  // Helper: Create Conversation via Cloud Function
  Future<void> _createConversationForId(String convId) async {
    if (convId.startsWith('gp_')) {
      final uidsStr = convId.substring(3);
      final uids = uidsStr.split('_');
      await FirebaseFunctions.instance
          .httpsCallable('startGroupConversation')
          .call({'participants': uids});
    } else if (convId.startsWith('dm_')) {
      final parts = convId.substring(3).split('_');
      if (parts.length == 2) {
        final me = _auth.currentUser?.uid;
        if (me == null) throw Exception("No Auth");
        final target = (parts[0] == me) ? parts[1] : parts[0];
        await FirebaseFunctions.instance
            .httpsCallable('startDM')
            .call({'targetUid': target});
      }
    }
  }

  // Helper: Get relevant conversation IDs for a Game (Group + Team)
  List<String> getGameConversationIds(
      String gameId, Map<String, dynamic> players) {
    // 1. All Players -> Group Chat
    // Filter out bots (uid starting with 'bot' or 'BOT')
    final allUids = players.keys
        .where((uid) =>
            !uid.toLowerCase().startsWith('bot') &&
            !uid.toLowerCase().startsWith('computer'))
        .toList();

    final gpId = getCanonicalId(allUids);

    final ids = <String>[];
    if (gpId != 'error_empty' && allUids.length > 1) {
      ids.add(gpId);
    }

    // 2. My Team -> Team Chat
    final myUid = _auth.currentUser?.uid;
    if (myUid != null && players.containsKey(myUid)) {
      final myTeam = players[myUid]['team'];
      // Only generic 'team' checking if team is not null (so works for team modes)
      if (myTeam != null) {
        final teamUids = players.entries
            .where((e) =>
                e.value['team'] == myTeam &&
                !e.key.toLowerCase().startsWith('bot'))
            .map((e) => e.key)
            .toList();

        // Valid team chat if > 1 person (myself + teammate)
        if (teamUids.length > 1) {
          final teamId = getCanonicalId(teamUids);
          // Only add if distinct from group (e.g. 2p game group == team, don't duplicate)
          if (teamId != gpId && teamId != 'error_empty') {
            ids.add(teamId);
          }
        }
      }
    }

    return ids;
  }

  // Public wrapper for UI initialization
  Future<String> ensureConversation(List<String> uids) async {
    final convId = getCanonicalId(uids);

    try {
      // Try to read verification.
      // Note: If conversation doesn't exist, Security Rules might throw Permission Denied.
      final snap = await _db.child('conversations/$convId/participants').get();
      if (!snap.exists) {
        debugPrint("Conversation $convId missing. Creating...");
        await _createConversationForId(convId);
      }
      return convId;
    } catch (e) {
      debugPrint("Error ensuring conversation (likely permission/missing): $e");
      // If we can't read it, we assume we need to create/join it.
      try {
        await _createConversationForId(convId);
      } catch (createErr) {
        debugPrint("Creation failed too: $createErr");
      }
      return convId;
    }
  }

  // Helper: Generate Canonical ID
  String getCanonicalId(List<String> uids) {
    if (uids.isEmpty) return 'error_empty';
    final sorted = List<String>.from(uids)..sort();

    // 1:1 -> dm_A_B
    // Group -> gp_A_B_C...
    if (sorted.length == 2) {
      return 'dm_${sorted[0]}_${sorted[1]}';
    } else {
      return 'gp_${sorted.join('_')}';
    }
  }

  // Stream: Single Conversation
  Stream<List<ActivityItem>> getConversationStream(String convId) {
    return _db
        .child('messages')
        .child(convId)
        .orderByChild('ts') // or timestamp
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ActivityItem> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final msgMap = Map<String, dynamic>.from(value);
            // Normalize ts/timestamp
            if (msgMap['timestamp'] == null && msgMap['ts'] != null) {
              msgMap['timestamp'] = msgMap['ts'];
            }
            if (msgMap['id'] == null) msgMap['id'] = key;
            messages.add(ActivityItem.fromMap(msgMap));
          } catch (e) {}
        }
      });
      messages
          .sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
      return messages;
    });
  }

  // Stream: Merged (for Game Overlay listening to Team DM + Group)
  Stream<List<ActivityItem>> getMergedActivityStream(List<String> convIds) {
    // Combine streams using Rx or manual merge?
    // Manual merge with rxdart is best, but standard Streams:
    // We can map each convId to a stream, then use StreamGroup (async package) or manual combine.
    // Simplifying: Just listen to multiple and combine in memory?
    // rxdart `CombineLatestStream` is simpler if available.
    // If not, we iterate.

    // Let's assume we can fetch them. For now, returning a stream that emits when ANY changes.
    // Implementation: simple Listeners management is complex here without rxdart.
    // I will use a custom StreamController logic for MVP.

    // Actually, for MVP, we might only need ONE active stream if 4P is not fully live.
    // But user asked for Merged.

    // Using a simplified approach: Listen to all, maintaining a Map<ConvId, List<Item>>, emit flattened list.

    StreamController<List<ActivityItem>> controller = StreamController();
    Map<String, List<ActivityItem>> cache = {};
    List<StreamSubscription> subs = [];

    controller.onListen = () {
      for (final cid in convIds) {
        subs.add(getConversationStream(cid).listen((items) {
          cache[cid] = items;

          // Flatten and Sort
          final all = cache.values.expand((x) => x).toList();
          all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          controller.add(all);
        }));
      }
    };

    controller.onCancel = () {
      for (var s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  // Deprecated: sendGameMessage (Dual Write is gone, now just Unified shim if needed)
  Future<void> sendGameMessage(String gameId, String text,
      {String type = 'text', bool isTeam = false, String? otherUid}) async {
    // Legacy support removed/breaking. Callers must migrate or use sendMessageToConversation.
    debugPrint("sendGameMessage is deprecated. Use sendMessageToConversation.");
  }

  // Method Alias for Activity Stream
  Future<void> sendActivity({
    required String toUid,
    String type = 'text',
    Map<String, dynamic> payload = const {},
    String? message,
  }) async {
    return sendDirectMessage(
        toUid: toUid, message: message ?? '', type: type, payload: payload);
  }

  // Stream for Global Chat
  Stream<List<ActivityItem>> getGlobalChat() {
    return _db
        .child('global_chat')
        .orderByChild('timestamp')
        // limitToLast disabled for Android compatibility
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ActivityItem> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final msgMap = Map<String, dynamic>.from(value);
            // Ensure ID is set from key if missing
            if (msgMap['id'] == null) msgMap['id'] = key;
            messages.add(ActivityItem.fromMap(msgMap));
          } catch (e) {
            // ignore malformed
          }
        }
      });

      // Sort Descending (Newest First)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return messages; // [Newest ... Oldest]
    });
  }

  // Stream for Game Chat
  Stream<List<ActivityItem>> getGameChat(String gameId) {
    return _db
        .child('game_chats')
        .child(gameId)
        .orderByChild('timestamp')
        // limitToLast disabled for Android compatibility
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ActivityItem> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final msgMap = Map<String, dynamic>.from(value);
            if (msgMap['id'] == null) msgMap['id'] = key;
            messages.add(ActivityItem.fromMap(msgMap));
          } catch (e) {
            // ignore
          }
        }
      });
      // Sort Descending (Newest First)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    });
  }

  // ... send methods will stay mostly same but create map manually or use ActivityItem toMap? ...
  // Updating sendGlobal to use ActivityItem for consistency
  Future<void> sendGlobalMessage(String text, {String type = 'text'}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final msgRef = _db.child('global_chat').push();
    // Use public parseType
    ActivityType aType = ActivityItem.parseType(type);

    final item = ActivityItem(
      id: msgRef.key!,
      senderId: user.uid,
      type: aType,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      text: text,
      isGlobal: true,
      senderName: user.displayName ?? 'Player',
      senderAvatar: user.photoURL,
    );

    final mapData = item.toMap()..removeWhere((key, value) => value == null);

    try {
      await msgRef.set(mapData);
    } catch (e) {
      debugPrint('Error sending global: $e');
    }
  }

  // ... sendGameMessage ...

  // Stream for 1:1 Chat
  Stream<List<ActivityItem>> getDirectChat(String peerId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    final chatId = (myUid.compareTo(peerId) < 0)
        ? 'dm_${myUid}_$peerId'
        : 'dm_${peerId}_$myUid';

    return _db
        .child('messages')
        .child(chatId)
        .orderByChild('ts')
        // limitToLast disabled for Android compatibility
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ActivityItem> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final msgMap = Map<String, dynamic>.from(value);
            // Map backend 'ts' to 'timestamp' if needed
            if (msgMap['timestamp'] == null && msgMap['ts'] != null) {
              msgMap['timestamp'] = msgMap['ts'];
            }
            if (msgMap['id'] == null) msgMap['id'] = key;

            messages.add(ActivityItem.fromMap(msgMap));
          } catch (e) {
            // ignore
          }
        }
      });
      // Sort Descending (Newest First)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    });
  }

  Future<void> sendDirectMessage({
    required String toUid,
    required String message,
    String type = 'text',
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> context = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final convId = (user.uid.compareTo(toUid) < 0)
        ? 'dm_${user.uid}_$toUid'
        : 'dm_${toUid}_${user.uid}';

    try {
      await FirebaseFunctions.instance.httpsCallable('sendMessage').call({
        'convId': convId,
        'text': message,
        'type': type,
        'payload': payload,
        'context': context
      });
    } catch (e) {
      if (e.toString().contains('not-found')) {
        await FirebaseFunctions.instance
            .httpsCallable('startDM')
            .call({'targetUid': toUid});
        // Retry
        await FirebaseFunctions.instance.httpsCallable('sendMessage').call({
          'convId': convId,
          'text': message,
          'type': type,
          'payload': payload,
          'context': context
        });
      } else {
        debugPrint("Send Error: $e");
        rethrow;
      }
    }
  }

  // -------------------------------------------------------------
  // Typing Indicators (Unified)
  // -------------------------------------------------------------

  String _getDmId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? 'dm_${uid1}_$uid2' : 'dm_${uid2}_$uid1';
  }

  // Deprecated: Peer-based helper
  Future<void> setTypingStatus(String peerId, bool isTyping) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final convId = _getDmId(user.uid, peerId);
    return setTypingStatusForConversation(convId, isTyping);
  }

  Future<void> setTypingStatusForConversation(
      String convId, bool isTyping) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // We use onDisconnect to ensure it clears if app crashes
    final ref = _db.child('conversations/$convId/typing/${user.uid}');

    if (isTyping) {
      await ref.set(true);
      await ref.onDisconnect().remove();
    } else {
      await ref.remove();
      await ref.onDisconnect().cancel();
    }
  }

  Stream<bool> getTypingStatusForConversation(String convId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db.child('conversations/$convId/typing').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return false;

      // Check if ANYONE else is typing (exclude self)
      bool someoneTyping = false;
      data.forEach((key, value) {
        if (key != user.uid && value == true) {
          someoneTyping = true;
        }
      });
      return someoneTyping;
    });
  }

  // Deprecated wrapper
  Stream<bool> getTypingStatus(String peerId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    final convId = _getDmId(user.uid, peerId);
    return getTypingStatusForConversation(convId);
  }
}
