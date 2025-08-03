class UserInfo {
  final String nickname;
  final String email;
  final String profileUrl; // 비어있을 수도 있음

  UserInfo({
    required this.nickname,
    required this.email,
    required this.profileUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    // 서버가 BaseResponse 형태로 감싸서 result 에 실제 데이터가 있다고 가정
    final data = json['result'] as Map<String, dynamic>;
    return UserInfo(
      nickname: data['nickname'] as String,
      email: data['email'] as String,
      profileUrl: data['profileUrl'] as String? ?? '🧑‍💻',
    );
  }
}
