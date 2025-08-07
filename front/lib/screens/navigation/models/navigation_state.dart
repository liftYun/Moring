import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class NavigationState {
  // 위치 관련 상태
  Position? currentPosition;
  Position? lastPosition;
  String currentSpeed = "0";
  
  // 목적지 관련 상태
  String destination = "";
  double destinationLat = 0.0;
  double destinationLng = 0.0;
  bool hasDestination = false;
  
  // 검색 관련 상태
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  
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
    final speed = double.tryParse(currentSpeed) ?? 0.0;
    return "${speed.toStringAsFixed(0)}km/h";
  }
  
  String get formattedDistanceToDestination {
    if (distanceToDestination < 1000) {
      return "${distanceToDestination.toStringAsFixed(0)}m";
    } else {
      return "${(distanceToDestination / 1000).toStringAsFixed(1)}km";
    }
  }
}
