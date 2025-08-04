class UserInfo {
  final String uuid;
  final String nickname;
  final String email;
  final String profileUrl;

  UserInfo({
    required this.uuid,
    required this.nickname,
    required this.email,
    this.profileUrl = '',
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      // null 이면 빈 문자열로 대체
      uuid: json['uuid'] as String? ?? '',
      nickname: json['nickName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      // 응답에 profileUrl 키가 없으면 빈 문자열
      profileUrl: json['profileUrl'] as String? ?? '🧑‍💻',
    );
  }
}
