import 'package:geolocator/geolocator.dart';

class LocationService {
  // 위치 권한 확인
  static Future<bool> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // 현재 위치 가져오기
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
    } catch (e) {
      print('❌ 현재 위치 가져오기 실패: $e');
      return null;
    }
  }
  
  // 위치 스트림 설정
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // 3미터마다 업데이트
        timeLimit: Duration(seconds: 2), // 2초마다 업데이트
      ),
    );
  }
  
  // 두 지점 간 거리 계산 (미터 단위)
  static double calculateDistance(
    double startLat, double startLng,
    double endLat, double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
  
  // 속도 변환 (m/s -> km/h)
  static double convertSpeedToKmh(double speedInMs) {
    return speedInMs * 3.6;
  }
  
  // 속도 필터링 (이동 평균)
  static double filterSpeed(List<double> speedBuffer, double newSpeed) {
    speedBuffer.add(newSpeed);
    if (speedBuffer.length > 5) {
      speedBuffer.removeAt(0);
    }
    
    double sum = speedBuffer.reduce((a, b) => a + b);
    return sum / speedBuffer.length;
  }
}
