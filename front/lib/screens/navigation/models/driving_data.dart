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
  
  // JSON 변환
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
    };
  }
  
  // JSON에서 생성
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
    );
  }
}
