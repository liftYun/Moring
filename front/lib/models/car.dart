class Car {
  final String vin; // 차대번호
  final String nickname; // 애칭
  final String modelName; // 모델명
  final String imgUrl; // 이미지 URL

  Car({
    required this.vin,
    required this.nickname,
    required this.modelName,
    required this.imgUrl,
  });

  // (선택 사항) API에서 JSON 데이터를 받아올 경우를 위한 팩토리 생성자
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      vin: json['vin'],
      nickname: json['nickname'],
      modelName: json['modelName'],
      imgUrl: json['imgUrl'] as String? ?? '',
    );
  }
}
