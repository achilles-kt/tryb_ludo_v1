import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import 'package:rxdart/rxdart.dart';

class SocialService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final SocialService instance = SocialService._();
  SocialService._();

  // 1. Stream Friends
  Stream<List<UserModel>> getFriends() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return _db.child('friends/$myUid').onValue.switchMap((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return Stream.value(<UserModel>[]);

      final friendUids = <String>[];
      data.forEach((key, value) {
        if (value == true) {
          friendUids.add(key as String);
        } else if (value is Map) {
          final status = value['status'];
          if (status == 'friend') {
            friendUids.add(key as String);
          }
        }
      });

      if (friendUids.isEmpty) return Stream.value(<UserModel>[]);

      final streams = friendUids.map((uid) {
        // PRE-FILTER: ID check
        if (uid.toLowerCase().startsWith('bot_') ||
            uid.toLowerCase().startsWith('computer_')) {
          return Stream.value(
              UserModel(id: 'BOT_HIDDEN', name: '', avatar: ''));
        }

        return _db.child('users/$uid/profile').onValue.map((profileEvent) {
          final profileData =
              profileEvent.snapshot.value as Map<dynamic, dynamic>? ?? {};

          // Double check name
          final name = profileData['name'] ?? profileData['displayName'] ?? '';
          if (name.toString().toLowerCase().contains('(bot)')) {
            return UserModel(id: 'BOT_HIDDEN', name: '', avatar: '');
          }

          return UserModel.fromMap(uid, profileData);
        });
      });

      return CombineLatestStream.list<UserModel>(streams).map((list) {
        // Remove any hidden bots
        return list.where((u) => u.id != 'BOT_HIDDEN').toList();
      }).asBroadcastStream();
    }).asBroadcastStream();
  }

  // 2. Stream Recent Players
  Stream<List<UserModel>> getRecentPlayers() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return Rx.combineLatest3(
      _db.child('recentlyPlayed/$myUid').onValue,
      _db.child('friends/$myUid').onValue,
      _db.child('suggestedFriends/$myUid').onValue,
      (DatabaseEvent recentEvent, DatabaseEvent friendEvent,
          DatabaseEvent suggestedEvent) {
        final recentData = recentEvent.snapshot.value;
        final friendData = friendEvent.snapshot.value;
        final suggestedData = suggestedEvent.snapshot.value;

        // 1. Parse Friends Map
        final friendsMap = <String, dynamic>{};
        if (friendData != null && friendData is Map) {
          friendsMap.addAll(friendData.cast<String, dynamic>());
        }

        // 0. Merge Data Sources
        final uniqueEntries = <String, int>{};

        // A. Add Pending Requests (Highest Priority - Fake future timestamp)
        if (friendData != null && friendData is Map) {
          friendData.forEach((key, value) {
            if (value is Map && value['status'] == 'pending') {
              // Give huge timestamp to float to top
              uniqueEntries[key as String] = 9999999999999;
            }
          });
        }

        // B. Add Recent
        if (recentData != null && recentData is Map) {
          recentData.forEach((key, value) {
            if (value is Map) {
              final ts = (value['lastPlayedAt'] as num?)?.toInt() ?? 0;
              // Don't overwrite if existing is "pending" (future ts)
              if (!uniqueEntries.containsKey(key) || uniqueEntries[key]! < ts) {
                uniqueEntries[key as String] = ts;
              }
            }
          });
        }

        // C. Add Suggested
        if (suggestedData != null && suggestedData is Map) {
          suggestedData.forEach((key, value) {
            if (value is Map) {
              final ts = (value['ts'] as num?)?.toInt() ?? 0;
              if (!uniqueEntries.containsKey(key)) {
                uniqueEntries[key as String] = ts;
              }
            }
          });
        }

        // 3. Sort by Timestamp Descending
        final sortedKeys = uniqueEntries.keys.toList();
        sortedKeys.sort((a, b) {
          final tA = uniqueEntries[a] ?? 0;
          final tB = uniqueEntries[b] ?? 0;
          return tB.compareTo(tA);
        });

        // 4. Filter & Map Status
        final filteredUidsWithStatus = <String, String>{}; // UID -> Status

        for (var uid in sortedKeys) {
          // BOT FILTER: specific ID patterns or bot names
          if (uid.toLowerCase().startsWith('bot_') ||
              uid.toLowerCase().startsWith('computer_')) {
            continue;
          }

          final fVal = friendsMap[uid];
          String status = 'none';

          if (fVal == true) {
            status = 'friend';
          } else if (fVal is Map) {
            status = fVal['status'] ?? 'none';
          }

          // Filter: Hide ONLY if already accepted friend (Allow pending/requested/none)
          if (status == 'friend') continue;

          filteredUidsWithStatus[uid] = status;
        }

        return filteredUidsWithStatus.entries
            .take(15) // Increased limit to accommodate requests
            .toList(); // MapEntry<String, String>
      },
    ).switchMap((List<MapEntry<String, String>> entries) {
      if (entries.isEmpty) return Stream.value(<UserModel>[]);

      final streams = entries.map((e) {
        final uid = e.key;
        final fStatus = e.value;
        return _db.child('users/$uid/profile').onValue.map((profileEvent) {
          final profileData =
              profileEvent.snapshot.value as Map<dynamic, dynamic>? ?? {};

          // Double check name if ID didn't catch it
          final name = profileData['name'] ?? profileData['displayName'] ?? '';
          if (name.toString().toLowerCase().contains('(bot)')) {
            // Return dummy to filter out in CombineLatest?
            // CombineLatest waits for all. Better to return a dummy UserModel and filter list
            return UserModel(id: 'BOT_HIDDEN', name: '', avatar: '');
          }

          return UserModel.fromMap(uid, profileData, friendStatus: fStatus);
        });
      });

      return CombineLatestStream.list<UserModel>(streams).map((list) {
        // Remove any hidden bots
        return list.where((u) => u.id != 'BOT_HIDDEN').toList();
      }).asBroadcastStream();
    }).asBroadcastStream();
  }

  // 3. Send Friend Request
  Future<void> sendFriendRequest(String targetUid) async {
    await FirebaseFunctions.instance.httpsCallable('sendFriendRequest').call({
      'targetUid': targetUid,
    });
  }

  // 4. Stream Incoming Requests
  Stream<List<UserModel>> getIncomingRequests() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return _db.child('friends/$myUid').onValue.switchMap((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return Stream.value(<UserModel>[]);

      final requestUids = <String>[];
      data.forEach((key, value) {
        if (value is Map) {
          if (value['status'] == 'pending') {
            requestUids.add(key as String);
          }
        }
      });

      if (requestUids.isEmpty) return Stream.value(<UserModel>[]);

      final streams = requestUids.map((uid) {
        return _db.child('users/$uid/profile').onValue.map((profileEvent) {
          final profileData =
              profileEvent.snapshot.value as Map<dynamic, dynamic>? ?? {};
          return UserModel.fromMap(uid, profileData);
        });
      });

      return CombineLatestStream.list<UserModel>(streams).asBroadcastStream();
    }).asBroadcastStream();
  }

  // 5. Respond to Request
  Future<void> respondToFriendRequest(String targetUid, String action) async {
    await FirebaseFunctions.instance
        .httpsCallable('respondToFriendRequest')
        .call({
      'targetUid': targetUid,
      'action': action // 'accept' or 'reject'
    });
  }

  // 6. Check if Contacts Synced
  Stream<bool> getContactsSyncedStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(false);
    return _db
        .child('users/$myUid/flags/contactsSynced')
        .onValue
        .map((event) => event.snapshot.value == true)
        .asBroadcastStream();
  }
}
