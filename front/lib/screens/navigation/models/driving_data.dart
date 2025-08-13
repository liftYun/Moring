class DrivingData {
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistance; // 미터 단위
  final double averageSpeed; // km/h
  final double maxSpeed; // km/h
  final String destination;
  final double destinationLat;
  final double destinationLng;
  final bool reachedDestination;

  // 🆕 4시간 주기 전송 상태 관리 필드들
  final bool isSentToServer;          // 서버 전송 완료 여부
  final DateTime? lastSentAttempt;    // 마지막 전송 시도 시간
  final int retryCount;               // 재시도 횟수

  DrivingData({
    required this.startTime,
    this.endTime,
    required this.totalDistance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.destination,
    required this.destinationLat,
    required this.destinationLng,
    required this.reachedDestination,
    // 🆕 새로운 필드들 (기본값 설정)
    this.isSentToServer = false,
    this.lastSentAttempt,
    this.retryCount = 0,
  });

  // 주행 시간 계산 (분 단위)
  int get drivingDurationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  // 주행 시간 포맷팅
  String get formattedDuration {
    final duration = endTime?.difference(startTime) ?? DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  // 거리 포맷팅
  String get formattedDistance {
    if (totalDistance < 1000) {
      return "${totalDistance.toStringAsFixed(1)}m";
    } else {
      return "${(totalDistance / 1000).toStringAsFixed(1)}km";
    }
  }

  // 🆕 전송 상태 업데이트를 위한 copyWith 메서드
  DrivingData copyWith({
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistance,
    double? averageSpeed,
    double? maxSpeed,
    String? destination,
    double? destinationLat,
    double? destinationLng,
    bool? reachedDestination,
    bool? isSentToServer,
    DateTime? lastSentAttempt,
    int? retryCount,
  }) {
    return DrivingData(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistance: totalDistance ?? this.totalDistance,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      destination: destination ?? this.destination,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      reachedDestination: reachedDestination ?? this.reachedDestination,
      isSentToServer: isSentToServer ?? this.isSentToServer,
      lastSentAttempt: lastSentAttempt ?? this.lastSentAttempt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  // JSON 변환 (🆕 새 필드들 포함)
  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'destination': destination,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'reachedDestination': reachedDestination,
      'drivingDurationMinutes': drivingDurationMinutes,
      // 🆕 새로운 필드들
      'isSentToServer': isSentToServer,
      'lastSentAttempt': lastSentAttempt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  // JSON에서 생성 (🆕 새 필드들 처리, 기존 데이터 호환성 유지)
  factory DrivingData.fromJson(Map<String, dynamic> json) {
    return DrivingData(
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      totalDistance: json['totalDistance'].toDouble(),
      averageSpeed: json['averageSpeed'].toDouble(),
      maxSpeed: json['maxSpeed'].toDouble(),
      destination: json['destination'],
      destinationLat: json['destinationLat'].toDouble(),
      destinationLng: json['destinationLng'].toDouble(),
      reachedDestination: json['reachedDestination'],
      // 🆕 새로운 필드들 (기존 데이터 호환을 위해 기본값 설정)
      isSentToServer: json['isSentToServer'] ?? false,
      lastSentAttempt: json['lastSentAttempt'] != null
          ? DateTime.parse(json['lastSentAttempt'])
          : null,
      retryCount: json['retryCount'] ?? 0,
    );
  }
}