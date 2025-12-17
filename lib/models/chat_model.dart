class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final String type; // 'text' or 'emoji'
  final bool isGlobal;
  final String? senderName;
  final String? senderAvatar;
  final bool isTeam;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.isGlobal = false,
    this.senderName,
    this.senderAvatar,
    this.isTeam = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'type': type,
      'isGlobal': isGlobal,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'isTeam': isTeam,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      type: map['type'] ?? 'text',
      isGlobal: map['isGlobal'] ?? false,
      senderName: map['senderName'],
      senderAvatar: map['senderAvatar'],
      isTeam: map['isTeam'] ?? false,
    );
  }
}
