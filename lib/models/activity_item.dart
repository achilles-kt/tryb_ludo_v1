enum ActivityType { text, gameInvite, gameResult, presenceUpdate, unknown }

class ActivityItem {
  final String id;
  final String senderId;
  final ActivityType type;
  final int timestamp;
  final String text;
  final Map<String, dynamic> payload; // Ensure String keys
  final Map<String, dynamic> context; // Ensure String keys

  // Legacy/UI helpers
  final String? senderName;
  final String? senderAvatar;
  final bool isGlobal;
  final bool isTeam;

  ActivityItem({
    required this.id,
    required this.senderId,
    required this.type,
    required this.timestamp,
    this.text = '',
    this.payload = const {},
    this.context = const {},
    this.senderName,
    this.senderAvatar,
    this.isGlobal = false,
    this.isTeam = false,
  });

  factory ActivityItem.fromMap(Map<dynamic, dynamic> map) {
    // Helper to get nested value from context or payload if not at root
    final context = Map<String, dynamic>.from(map['context'] as Map? ?? {});
    final payload = Map<String, dynamic>.from(map['payload'] as Map? ?? {});

    // Check root, then context for 'isTeam'
    bool checkIsTeam() {
      if (map['isTeam'] == true) return true;
      if (context['isTeam'] == true) return true;
      // Also check payload just in case schema drifted
      if (payload['isTeam'] == true) return true;
      return false;
    }

    return ActivityItem(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      type: parseType(map['type']), // Updated to public
      timestamp: (map['timestamp'] ?? map['ts'] ?? 0) as int,
      text: map['text']?.toString() ?? '',
      payload: payload,
      context: context,
      senderName: map['senderName']?.toString(),
      senderAvatar: map['senderAvatar']?.toString(),
      isGlobal: map['isGlobal'] == true,
      isTeam: checkIsTeam(),
    );
  }

  // ... (toMap remains same)

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'type': _typeToString(type),
      'timestamp': timestamp,
      'text': text,
      'payload': payload,
      'context': context,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'isGlobal': isGlobal,
      'isTeam': isTeam,
    };
  }

  String _typeToString(ActivityType type) {
    switch (type) {
      case ActivityType.gameResult:
        return 'game_result';
      case ActivityType.gameInvite:
        return 'game_invite';
      case ActivityType.presenceUpdate:
        return 'presence';
      case ActivityType.text:
        return 'text';
      default:
        return 'text';
    }
  }

  static ActivityType parseType(dynamic type) {
    if (type == null) return ActivityType.text;
    final str = type.toString();
    // Map legacy strings
    if (str == 'text') return ActivityType.text;
    if (str == 'game_result') return ActivityType.gameResult;
    if (str == 'game_invite') return ActivityType.gameInvite;
    if (str == 'presence') return ActivityType.presenceUpdate;

    // Fallback to name match
    for (var value in ActivityType.values) {
      if (value.name == str) return value;
    }
    return ActivityType.unknown;
  }
}
