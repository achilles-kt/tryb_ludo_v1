import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

class InviteService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<String> createPrivateTable() async {
    try {
      final result =
          await _functions.httpsCallable('createPrivateTable').call();
      final data = result.data as Map<dynamic, dynamic>;

      if (data['success'] == true && data['hostUid'] != null) {
        return data['hostUid'];
      } else {
        throw Exception(
            "Failed to create table: ${data['error'] ?? 'Unknown error'}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinPrivateGame(String hostUid) async {
    try {
      final result = await _functions.httpsCallable('joinPrivateGame').call({
        'hostUid': hostUid,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      rethrow;
    }
  }

  // --- Enhanced Invite System (Robust) ---

  Future<String> sendInvite(String hostUid) async {
    try {
      final result = await _functions.httpsCallable('sendInvite').call({
        'hostUid': hostUid,
      });
      final data = result.data as Map;
      return data['inviteId'];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> respondToInvite(
      String inviteId, String response) async {
    try {
      final result = await _functions.httpsCallable('respondToInvite').call({
        'inviteId': inviteId,
        'response': response, // 'accept' or 'reject'
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelInvite(String inviteId) async {
    try {
      await _functions.httpsCallable('cancelInvite').call({
        'inviteId': inviteId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Listen to a specific invite (for the Guest to see if Host Accepted/Rejected)
  Stream<DatabaseEvent> watchInvite(String inviteId) {
    return _database.ref('invites/$inviteId').onValue;
  }

  /// Listen to all PENDING invites for me (For the Host to see incoming requests)
  /// Used by the Global Overlay
  Stream<DatabaseEvent> watchIncomingInvites(String myUid) {
    return _database
        .ref('invites')
        .orderByChild('hostUid')
        .equalTo(myUid)
        .onValue;
  }

  Stream<DatabaseEvent> watchUserGameStatus(String uid) {
    return _database.ref('userGameStatus/$uid').onValue;
  }
}
