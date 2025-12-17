import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for Global Chat
  Stream<List<ChatMessage>> getGlobalChat() {
    // limitToLast removed to fix Android ClassCastException (Long vs Integer)
    return _db
        .child('global_chat')
        .orderByChild('timestamp')
        // .limitToLast(50)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ChatMessage> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            // value is likely linkedmap, cast safely
            final msgMap = Map<String, dynamic>.from(value as Map);
            messages.add(ChatMessage.fromMap(msgMap));
          } catch (e) {
            // ignore malformed
          }
        }
      });

      // Sort in memory as well to be sure
      messages
          .sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first?

      debugPrint(
          '🔍 Chat: Received Valid | Source: Global | Count: ${messages.length}');

      return messages.reversed
          .toList(); // Oldest first for UI (bottom to top usually)
    });
  }

  // Stream for Game Chat
  Stream<List<ChatMessage>> getGameChat(String gameId) {
    return _db
        .child('game_chats')
        .child(gameId)
        .orderByChild('timestamp')
        // .limitToLast(50)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final List<ChatMessage> messages = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final msgMap = Map<String, dynamic>.from(value as Map);
            messages.add(ChatMessage.fromMap(msgMap));
          } catch (e) {
            // ignore
          }
        }
      });
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint(
          '🔍 Chat: Received Valid | Source: Game | Count: ${messages.length}');
      return messages;
    });
  }

  Future<void> sendGlobalMessage(String text, {String type = 'text'}) async {
    final user = _auth.currentUser;
    if (user == null) return; // Anonymous allow?

    final msgRef = _db.child('global_chat').push();
    final msg = ChatMessage(
      id: msgRef.key!,
      senderId: user.uid,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      isGlobal: true,
      senderName: user.displayName ?? 'Player',
      senderAvatar: user.photoURL, // null is fine
    );

    // Sanitize map (remove nulls) to be safe with platform channels
    final mapData = msg.toMap()..removeWhere((key, value) => value == null);

    debugPrint(
        '🔍 Chat: Attempting Write | Path: global_chat/${msg.id} | Data: $mapData');

    try {
      await msgRef.set(mapData);
      debugPrint(
          '🔍 Chat: In DB (Success) | User: ${user.uid} | Global | MsgID: ${msg.id}');
    } catch (e) {
      debugPrint('❌ Chat: DB Error | User: ${user.uid} | Global | Error: $e');
    }
  }

  Future<void> sendGameMessage(String gameId, String text,
      {String type = 'text', bool isTeam = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final msgRef = _db.child('game_chats').child(gameId).push();
    final msg = ChatMessage(
      id: msgRef.key!,
      senderId: user.uid,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      isGlobal: false,
      senderName: user.displayName ?? 'Player',
      senderAvatar: user.photoURL,
      isTeam: isTeam,
    );

    await msgRef.set(msg.toMap());
  }
}
