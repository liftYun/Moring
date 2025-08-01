class Vehicle {
  final String vin; // 차대번호
  final String nickname; // 애칭
  final String modelName; // 모델명

  Vehicle({
    required this.vin,
    required this.nickname,
    required this.modelName,
  });

  // (선택 사항) API에서 JSON 데이터를 받아올 경우를 위한 팩토리 생성자
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vin: json['vin'],
      nickname: json['nickname'],
      modelName: json['modelName'],
    );
  }
}