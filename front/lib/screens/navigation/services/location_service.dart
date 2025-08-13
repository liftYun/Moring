import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'speed_smoother.dart';

class LocationService {
  // ====== 튜닝 파라미터 ======
  static const double maxVehicleSpeedMps = 60.0; // 216km/h 이상은 이상치로 간주
  static const double maxAccelMps2 = 8.0;        // 비현실 가속/감속 컷
  static const double maxJumpMeters = 120.0;     // 한 스텝에서 이 이상 점프면 이상치
  static const double minStepMeters = 0.5;       // 너무 작은 흔들림 제거
  static const double maxHAccMeters = 25.0;      // 수평 정확도 허용치(둘 중 하나라도 넘으면 제외)
  static const Duration maxGap = Duration(seconds: 10); // 너무 긴 gap은 보수적으로 처리

  // ====== 권한/현재 위치/스트림 ======
  static Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

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
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('❌ 현재 위치 가져오기 실패: $e');
      return Geolocator.getLastKnownPosition();
    }
  }

  static Stream<Position> getLocationStream() {
    debugPrint('📍 위치 스트림 설정 시작...');

    // 안드로이드 전용 설정
    AndroidSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high, // 높은 정확도
      distanceFilter: 3, // 3미터마다 업데이트
      intervalDuration: Duration(seconds: 2), // 2초마다 업데이트
      forceLocationManager: false, // Google Play Services 사용
    );

    debugPrint('📍 위치 설정: distanceFilter=3m, interval=2s');

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .handleError((error) {
      debugPrint('❌ 위치 스트림 에러: $error');

      if (error is LocationServiceDisabledException) {
        debugPrint('❌ 위치 서비스가 비활성화되었습니다.');
      } else if (error is PermissionDeniedException) {
        debugPrint('❌ 위치 권한이 거부되었습니다.');
      } else if (error is PositionUpdateException) {
        debugPrint('❌ 위치 업데이트 실패: ${error.message}');
      }
    });
  }

  // ====== 속도 필터 (EMA + 안전장치) ======
  static final _smoother = SpeedSmoother(maxKmh: 200, maxAccelKmhPerS: 35);
  static Position? _lastPos; // 이전 Position 기록(좌표/시간 기반 속도 계산용)
  static DateTime? _lastTsOverride; // Position.timestamp 가 null일 때 대신 쓸 타임스탬프

  // 노이즈 바닥치(좌표/시간 기반 속도 계산 시 작은 흔들림 제거)
  static const double _minMoveMetersFloor = 4.0; // 최소 이동치
  static const double _accuracyFactor     = 1.3; // accuracy * factor 보다 작으면 노이즈

  static double computeFilteredSpeed(Position pos, {double alpha = 0.35}) {
    // 1) 센서 기반 m/s → km/h
    double kmhSensor = convertSpeedToKmh(math.max(0.0, pos.speed));

    // 2) 좌표/시간 기반 폴백 (m/s → km/h)
    double? kmhFromDelta;
    final nowTs = pos.timestamp ?? _lastTsOverride ?? DateTime.now();

    if (_lastPos != null) {
      final prev = _lastPos!;
      final prevTs = prev.timestamp ?? _lastTsOverride ?? nowTs;
      final dt = (nowTs.difference(prevTs).inMilliseconds / 1000.0).clamp(0.0, 60.0);

      if (dt > 0) {
        final meters = calculateDistance(prev.latitude, prev.longitude, pos.latitude, pos.longitude);

        // accuracy 기반 노이즈 제거
        final acc = (pos.accuracy.isNaN || pos.accuracy.isInfinite || pos.accuracy <= 0)
            ? _minMoveMetersFloor
            : pos.accuracy;
        final noiseFloor = math.max(_minMoveMetersFloor, acc * _accuracyFactor);

        final effectiveMeters = meters < noiseFloor ? 0.0 : meters;
        kmhFromDelta = convertSpeedToKmh(effectiveMeters / dt);
      }
    }

    _lastPos = pos;
    _lastTsOverride = nowTs;

    // 3) 센서값이 빈약할 때 폴백 사용
    double rawKmh = kmhSensor; // 기본은 센서 속도값을 사용
    if (rawKmh.isNaN || rawKmh.isInfinite || rawKmh < 0.5) {
      if (kmhFromDelta != null) rawKmh = kmhFromDelta;
    }

    // 4) EMA 스무딩 (rawKmh는 km/h → 내부는 m/s로 통일해서 처리)
    final filtered = _smoother.push(
      rawMs: rawKmh / 3.6,
      ts: nowTs,
    );

    return filtered;
  }

  // ====== 주행거리(미터) 계산: 이상치 억제판 ======
  /// 이전/현재 Position을 모두 넘겨주세요.
  /// 반환값: 누적할 "증가분(m)". 이상치로 판단되면 0을 돌려서 누적하지 않습니다.
  static double calculateDistanceRobust(Position prev, Position curr) {
    // 1) 수평 정확도(HAcc) 필터
    final prevAcc = prev.accuracy.isFinite ? prev.accuracy : double.infinity;
    final currAcc = curr.accuracy.isFinite ? curr.accuracy : double.infinity;
    if (prevAcc > maxHAccMeters || currAcc > maxHAccMeters) {
      // debugPrint('🚫 GPS 정확도 부족: prev=${prevAcc.toStringAsFixed(1)}m, curr=${currAcc.toStringAsFixed(1)}m');
      return 0.0;
    }

    // 2) 시간차
    final DateTime t0 = prev.timestamp ?? DateTime.now();
    final DateTime t1 = curr.timestamp ?? DateTime.now();
    final dt = t1.difference(t0);
    if (dt.isNegative || dt.inMilliseconds == 0) {
      // debugPrint('🚫 시간 오류: dt=${dt.inMilliseconds}ms');
      return 0.0;
    }
    final seconds = dt.inMilliseconds / 1000.0;

    // 3) 좌표 거리(Haversine, 미터)
    final d = _haversineMeters(
      prev.latitude, prev.longitude, curr.latitude, curr.longitude,
    );

    // 4) 관측 속도 & 상한
    final observedV = d / seconds; // m/s
    if (!observedV.isFinite) return 0.0;
    if (observedV > maxVehicleSpeedMps) {
      debugPrint('🚫 비현실적 속도: ${(observedV * 3.6).toStringAsFixed(1)}km/h > ${(maxVehicleSpeedMps * 3.6).toStringAsFixed(1)}km/h');
      return 0.0;
    }

    // 5) 장거리 점프 컷
    if (d > maxJumpMeters) {
      debugPrint('🚫 장거리 점프: ${d.toStringAsFixed(1)}m > ${maxJumpMeters}m');
      // 하지만 gap이 길면 약간은 허용. 과대 누적 방지 위해 최소화
      if (dt > maxGap) {
        // conservative: 속도 정보가 있으면 v * dt, 없으면 0 처리
        final v = (curr.speed.isFinite && curr.speed > 0) ? curr.speed : 0.0;
        final est = (v * seconds).clamp(0.0, maxJumpMeters * 0.25); // 최대 1/4만 인정
        debugPrint('📐 장시간 gap 보정: ${est.toStringAsFixed(1)}m (원본: ${d.toStringAsFixed(1)}m)');
        return est;
      }
      return 0.0;
    }

    // 6) 속도 센서와의 일관성 검사(있을 때)
    if (curr.speed.isFinite && curr.speedAccuracy != null && curr.speedAccuracy!.isFinite) {
      final diff = (observedV - curr.speed).abs();
      if (diff > (3 * curr.speedAccuracy! + 3.0)) {
        debugPrint('🚫 속도 불일치: 관측=${(observedV * 3.6).toStringAsFixed(1)}km/h, 센서=${(curr.speed * 3.6).toStringAsFixed(1)}km/h');
        return 0.0;
      }
    }

    // 7) 비현실 가속도 컷(이전 speed가 있을 때만 효과적. 없으면 스킵)
    if (prev.speed.isFinite) {
      final dv = (observedV - prev.speed).abs(); // m/s
      final a = dv / seconds;
      if (a > maxAccelMps2 && observedV > 15.0) {
        debugPrint('🚫 비현실적 가속도: ${a.toStringAsFixed(1)}m/s² > ${maxAccelMps2}m/s²');
        return 0.0;
      }
    }

    // 8) 너무 작은 흔들림 제거
    if (d < minStepMeters) {
      return 0.0;
    }

    // debugPrint('✅ 유효한 이동: ${d.toStringAsFixed(1)}m, 속도: ${(observedV * 3.6).toStringAsFixed(1)}km/h');
    return d;
  }

  // 두 지점 간 거리 계산 (미터 단위) - 기존 호환성을 위해 유지
  static double calculateDistance(double startLat, double startLng,
      double endLat, double endLng,) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // 속도 변환 (m/s -> km/h)
  static double convertSpeedToKmh(double speedInMs) {
    return speedInMs * 3.6;
  }

  // 스무더 상태 초기화 (주행 시작/종료 시 호출 추천)
  static void resetSpeedFilter() {
    _smoother.reset();
    _lastPos = null;
    _lastTsOverride = null;
    // debugPrint('🔄 속도 필터 초기화');
  }

  // ====== 경로 라인까지 최단거리(미터) ======
  static double calculateDistanceToRouteLine({
    required Position currentPosition,
    required List<Map<String, double>> routeCoordinates,
  }) {
    if (routeCoordinates.length < 2) return double.infinity;

    final lat = currentPosition.latitude;
    final lng = currentPosition.longitude;

    double best = double.infinity;
    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      final a = routeCoordinates[i];
      final b = routeCoordinates[i + 1];
      final d = _pointToSegmentDistanceMeters(
        lat, lng, a['latitude']!, a['longitude']!, b['latitude']!, b['longitude']!,
      );
      if (d < best) best = d;
    }
    return best;
  }

  // 현재 위치에서 경로의 나머지 부분까지의 거리 계산
  static double calculateRemainingRouteDistance({
    required Position? currentPosition,
    required List<Map<String, double>> routeCoordinates,
    required double fallbackDistance,
  }) {
    if (routeCoordinates.isEmpty || currentPosition == null) {
      return fallbackDistance; // 경로가 없으면 직선 거리 반환
    }

    // 1. 현재 위치와 가장 가까운 경로상의 점 찾기
    int closestPointIndex = findClosestPointOnRoute(
      currentPosition: currentPosition,
      routeCoordinates: routeCoordinates,
    );

    // 2. 가장 가까운 점부터 목적지까지의 경로 거리 계산
    double remainingDistance = 0.0;

    // 현재 위치에서 가장 가까운 경로 점까지의 거리
    if (closestPointIndex < routeCoordinates.length) {
      final closestPoint = routeCoordinates[closestPointIndex];

      remainingDistance += calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        closestPoint['latitude']!,
        closestPoint['longitude']!,
      );

      // 가장 가까운 점부터 목적지까지의 경로상 거리
      for (int i = closestPointIndex; i < routeCoordinates.length - 1; i++) {
        remainingDistance += calculateDistance(
          routeCoordinates[i]['latitude']!,
          routeCoordinates[i]['longitude']!,
          routeCoordinates[i + 1]['latitude']!,
          routeCoordinates[i + 1]['longitude']!,
        );
      }
    }

    return remainingDistance;
  }

  // 현재 위치와 가장 가까운 경로상의 점 찾기
  static int findClosestPointOnRoute({
    required Position? currentPosition,
    required List<Map<String, double>> routeCoordinates,
  }) {
    if (routeCoordinates.isEmpty || currentPosition == null) return 0;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routeCoordinates.length; i++) {
      double distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        routeCoordinates[i]['latitude']!,
        routeCoordinates[i]['longitude']!,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  // ====== 내부 유틸 ======
  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // m
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _pointToSegmentDistanceMeters(
      double lat, double lon,
      double lat1, double lon1,
      double lat2, double lon2,
      ) {
    // equirectangular projection 근사로 평면화 후 거리 계산 (짧은 구간에서 충분히 정확)
    final phi = _deg2rad((lat1 + lat2) / 2.0);
    final x = (_deg2rad(lon) - _deg2rad(lon1)) * math.cos(phi);
    final y = _deg2rad(lat) - _deg2rad(lat1);
    final x2 = (_deg2rad(lon2) - _deg2rad(lon1)) * math.cos(phi);
    final y2 = _deg2rad(lat2) - _deg2rad(lat1);

    final segLen2 = x2 * x2 + y2 * y2;
    if (segLen2 == 0) {
      // a==b인 경우 점-점 거리
      return (_earthR * math.sqrt(x * x + y * y));
    }
    double t = (x * x2 + y * y2) / segLen2;
    t = t.clamp(0.0, 1.0);
    final projX = x2 * t;
    final projY = y2 * t;
    final dx = x - projX;
    final dy = y - projY;
    return _earthR * math.sqrt(dx * dx + dy * dy);
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static const double _earthR = 6371000.0; // meters
}