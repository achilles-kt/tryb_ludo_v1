import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  StreamSubscription? _connectionSub;

  // Track local game state to filter notifications
  String? _activeGameId;
  String? get currentPlayingGameId => _activeGameId;

  // Initialize Presence System
  // Should be called on App Start (after Auth)
  void initialize() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _setupDisconnectHook(user.uid);
        setOnline();
      } else {
        _connectionSub?.cancel();
        _activeGameId = null;
      }
    });

    // Monitor .info/connected to handle connection drops
    _connectionSub = _db.child('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected && _auth.currentUser != null) {
        _setupDisconnectHook(_auth.currentUser!.uid);
        // We re-assert 'online' (or current state) on reconnect
        // For simplicity, default to online. If in game, GameScreen should re-assert playing.
        setOnline();
      }
    });
  }

  void _setupDisconnectHook(String uid) {
    // When client disconnects, set state to 'offline'
    final statusRef = _db.child('status/$uid');
    try {
      // Use granular paths to avoid Map serialization issues
      statusRef.child('state').onDisconnect().set('offline');
      statusRef.child('last_changed').onDisconnect().set(ServerValue.timestamp);
    } catch (e) {
      debugPrint("❌ PRESENCE Hook Error: $e");
    }
  }

  Future<void> setOnline() async {
    _activeGameId = null; // Clear active game
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint("🟢 PRESENCE: Setting ${user.uid} to ONLINE");
    try {
      // Granular updates
      await _db.child('status/${user.uid}/state').set('online');
      await _db
          .child('status/${user.uid}/last_changed')
          .set(ServerValue.timestamp);
      await _db.child('status/${user.uid}/gameId').remove(); // Clear gameId
    } catch (e) {
      debugPrint("❌ PRESENCE Error (setOnline): $e");
    }
  }

  Future<void> setPlaying(String gameId) async {
    _activeGameId = gameId; // Set active game
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint("🎮 PRESENCE: Setting ${user.uid} to PLAYING ($gameId)");
    try {
      await _db.child('status/${user.uid}/state').set('playing');
      await _db
          .child('status/${user.uid}/last_changed')
          .set(ServerValue.timestamp);
      await _db.child('status/${user.uid}/gameId').set(gameId);
    } catch (e) {
      debugPrint("❌ PRESENCE Error (setPlaying): $e");
    }
  }

  Future<void> setOffline() async {
    _activeGameId = null;
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint("⚫ PRESENCE: Setting ${user.uid} to OFFLINE");
    try {
      await _db.child('status/${user.uid}/state').set('offline');
      await _db
          .child('status/${user.uid}/last_changed')
          .set(ServerValue.timestamp);
    } catch (e) {
      debugPrint("❌ PRESENCE Error (setOffline): $e");
    }
  }

  // Stream for a specific user's status
  Stream<Map<String, dynamic>> getUserStatus(String uid) {
    return _db.child('status/$uid').onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) {
        return {'state': 'offline', 'last_changed': 0};
      }
      if (val is String) {
        return {'state': val, 'last_changed': 0};
      }
      if (val is! Map) {
        return {'state': 'offline', 'last_changed': 0};
      }
      return Map<String, dynamic>.from(val);
    });
  }
}
