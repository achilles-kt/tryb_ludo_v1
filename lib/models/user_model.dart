class UserModel {
  final String id;
  final String name;
  final String avatar;
  final String status; // 'online', 'offline', 'in_game'
  final bool isFriend;
  final String friendStatus; // 'none', 'friend', 'requested', 'pending'

  UserModel({
    required this.id,
    required this.name,
    required this.avatar,
    this.status = 'offline',
    this.isFriend = false,
    this.friendStatus = 'none',
  });

  factory UserModel.fromMap(String id, Map<dynamic, dynamic> data,
      {String friendStatus = 'none'}) {
    return UserModel(
      id: id,
      name: data['name'] ?? data['displayName'] ?? 'Unknown',
      avatar: data['photoUrl'] ?? data['avatar'] ?? data['avatarUrl'] ?? '',
      status: data['status'] ?? 'offline',
      friendStatus: friendStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatar': avatar,
      'status': status,
    };
  }
}
