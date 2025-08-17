import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moring/screens/navigation/services/location_service.dart';

class NavigationState {
  // 위치 관련 상태
  Position? currentPosition;
  Position? lastPosition;
  // String currentSpeed = "0";
  double currentSpeed = 0.0;

  // 목적지 관련 상태
  String destination = "";
  double destinationLat = 0.0;
  double destinationLng = 0.0;
  bool hasDestination = false;

  // 검색 관련 상태
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  bool isSearchFocused = false; // ✅ 검색바 포커스 상태 추가

  // 경로 관련 상태
  List<Map<String, double>> routeCoordinates = [];
  bool isCalculatingRoute = false;
  String estimatedTime = '';
  String estimatedDistance = '';
  String trafficInfo = '';
  double routeDistance = 0.0;
  double distanceToDestination = 0.0;

  // 주행 관련 상태
  bool isDriving = false;
  double totalDrivingDistance = 0.0;
  DateTime? drivingStartTime;
  double maxSpeed = 0.0;
  List<double> speedHistory = [];

  // 속도 필터링 관련
  List<double> speedBuffer = [];
  static const int speedBufferSize = 5;

  // 지도 관련 상태
  GoogleMapController? mapController;
  bool isMapReady = false;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // 정지 감지 상태 & 튜닝 파라미터
  bool isStopped = false;                 // 현재 정지로 판정됐는지
  DateTime? stoppedSince;                 // low-speed가 시작된 시각
  static const double stopKmhThreshold = 8.0;               // 이 속도 이하를 "정지 후보"로 간주 (GPS 노이즈 고려)
  static const Duration stopHold = Duration(seconds: 4);     // 이 시간 이상 유지되면 0으로 고정 (더 안정적인 감지)
  static const double moveKmhThreshold = 12.0;              // 이 속도 이상이면 확실히 움직임으로 판정

  // 주행 통계
  double get averageSpeed {
    if (speedHistory.isEmpty) return 0.0;
    return speedHistory.reduce((a, b) => a + b) / speedHistory.length;
  }

  String get formattedDrivingTime {
    if (drivingStartTime == null) return "00:00";
    final duration = DateTime.now().difference(drivingStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  String get formattedTotalDistance {
    if (totalDrivingDistance < 1000) {
      return "${totalDrivingDistance.toStringAsFixed(1)}m";
    } else {
      return "${(totalDrivingDistance / 1000).toStringAsFixed(1)}km";
    }
  }

  String get formattedCurrentSpeed {
    // final speed = double.tryParse(currentSpeed) ?? 0.0;
    // return "${speed.toStringAsFixed(0)}";

    return currentSpeed.toStringAsFixed(0);
  }

  String get formattedDistanceToDestination {
    if (distanceToDestination < 1000) {
      return "${distanceToDestination.toStringAsFixed(0)}m";
    } else {
      return "${(distanceToDestination / 1000).toStringAsFixed(1)}km";
    }
  }

  String get formattedRemainingDistance {
    if (!hasDestination) return "0m";

    // LocationService를 통해 남은 거리 계산
    double remainingRouteDistance = LocationService.calculateRemainingRouteDistance(
      currentPosition: currentPosition,
      routeCoordinates: routeCoordinates,
      fallbackDistance: distanceToDestination,
    );

    if (remainingRouteDistance < 1000) {
      return "${remainingRouteDistance.toStringAsFixed(0)}m";
    } else {
      return "${(remainingRouteDistance / 1000).toStringAsFixed(1)}km";
    }
  }

  /// 정지 히스테리시스 적용: 일정 시간 저속이면 0으로 고정
  /// - [kmh] : 필터링된 실제 속도(km/h)
  /// - [ts]  : 이번 샘플의 타임스탬프
  double applyStopHysteresis(double kmh, DateTime ts) {
    final bool isLow = kmh <= stopKmhThreshold;  // 8km/h 이하 저속 감지
    final bool isHigh = kmh >= moveKmhThreshold; // 12km/h 이상 확실한 움직임

    if (isLow) {
      // 저속 구간이 시작되면 시작 시각 기록
      stoppedSince ??= ts;

      // 지정된 시간(4초) 이상 저속 유지 → 정지로 전환
      if (!isStopped && ts.difference(stoppedSince!).abs() >= stopHold) {
        isStopped = true;
        debugPrint('🛑 정지 상태로 전환: ${kmh.toStringAsFixed(1)}km/h로 ${stopHold.inSeconds}초간 유지');
      }
    } else if (isHigh) {
      // 확실한 움직임이 감지되면 즉시 정지 상태 해제
      if (isStopped) {
        debugPrint('🚗 움직임 감지로 정지 해제: ${kmh.toStringAsFixed(1)}km/h');
      }
      stoppedSince = null;
      isStopped = false;
    }
    // 8~12km/h 사이는 애매한 구간이므로 현재 상태 유지

    // 정지 상태면 0으로 강제, 아니면 실제 속도 반환
    return isStopped ? 0.0 : kmh;
  }

}
