//lib/screens/navigation/navigation_page.dart
import 'dart:math' as math;
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'package:moring/main.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/car_provider.dart';

// 서비스들
import '../../utils/custom_app_bar.dart';
import 'services/kakao_api_service.dart';
import 'services/location_service.dart';
import 'services/driving_log_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 모델들
import 'models/navigation_state.dart';
import 'models/driving_data.dart';

// 위젯들
import 'widgets/speed_overlay.dart';
import 'widgets/search_bar.dart';
import 'widgets/destination_info.dart';
import 'widgets/driving_controls.dart';
import 'widgets/search_results_dialog.dart';
import 'widgets/my_location_button.dart';
import 'widgets/heading_follow_button.dart';
// ⬇️ 네비에서 쓰는 SSE 알림(TTS) + 음성비서 패널
import 'package:moring/screens/navigation/sse_only.dart';
import 'package:moring/voice/moring_voice_panel.dart';

// ⬇️ SSE 전용 오버레이 (LLM/음성 제거)
import 'package:moring/screens/navigation/sse_only.dart';
import 'package:moring/voice/moring_voice_panel.dart';
// 🔹 마지막 사용자/시스템 활동 시각(ms)
int _lastActivityMs = 0;

class NavigationPage extends ConsumerStatefulWidget {
  const NavigationPage({super.key});

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> with WidgetsBindingObserver, RouteAware {
  // 네비게이션 상태
  final NavigationState _state = NavigationState();

  // 검색 관련
  final TextEditingController _searchController = TextEditingController();

  // 자동 경로 재계산 관련
  Timer? _routeRecalculationTimer;
  static const Duration _routeRecalculationInterval = Duration(minutes: 3);

  // 🆕 실시간 시간 업데이트 타이머
  Timer? _timeUpdateTimer;

  // 위치 스트림 구독
  StreamSubscription<Position>? _locationSubscription;

  // 키보드 가시성 상태
  bool _isKeyboardVisible = false;

  // 🆕 자동 측정 상태 (화면 생명주기에 의해 제어)
  bool _isAutoMeasuring = false;           // 자동 측정 중인지
  DateTime? _autoStartTime;                // 자동 측정 시작 시간
  double _autoTotalDistance = 0.0;         // 자동 측정된 총 거리
  double _autoMaxSpeed = 0.0;              // 자동 측정 중 최고 속도
  List<double> _autoSpeedHistory = [];     // 자동 측정 속도 기록
  Position? _autoLastPosition;             // 자동 측정용 이전 위치

  // 🆕 경로 안내 상태
  bool _isRouteGuiding = false;            // 경로 안내 중인지

  // 🆕 경로 전용 시간 측정 (목적지가 있을 때 사용)
  DateTime? _routeStartTime;               // 경로 시작 시간 (버튼 클릭 시점)

  // 주행 상태 표시
  bool _lastDrivingStatus = false;
  bool _hasInitializedDrivingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeLocation();
    });

    // 나침반 구독 (정지/저속에서 사용)
    _compassSub = FlutterCompass.events?.listen((event) {
      final h = event.heading; // 0~360 (null 가능)
      if (h != null && h.isFinite) {
        _compassHeadingDeg = (h + 360) % 360;
      }
    });

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteObserver 등록 - 정확한 화면 생명주기 감지
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      // debugPrint('🔄 NavigationPage RouteObserver 등록 완료');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _routeRecalculationTimer?.cancel();
    _timeUpdateTimer?.cancel(); // 🆕 시간 업데이트 타이머 정리
    _locationSubscription?.cancel();
    _compassSub?.cancel();

    // 네비 화면 나갈 때 자동 측정 저장
    _saveAutoMeasurement();

    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _showSnackBarSafe(SnackBar bar) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(bar);
      }
    });
  }

  // ==================== RouteAware 생명주기 함수들 ====================

  @override
  void didPush() {
    // 네비게이션 화면에 처음 들어왔을 때
    debugPrint('🚗 NavigationPage 화면 진입 (didPush) - 자동 측정 시작');
    _startAutoMeasurement();
  }

  @override
  void didPopNext() {
    // 다른 화면에서 돌아왔을 때
    debugPrint('🚗 NavigationPage 화면 복귀 (didPopNext) - 자동 측정 시작');
    _startAutoMeasurement();
  }

  @override
  void didPushNext() {
    // 이 화면 위에 다른 화면이 push되었을 때
    debugPrint('🛑 NavigationPage 화면 가려짐 (didPushNext) - 자동 측정 저장');
    _saveAutoMeasurement();
  }

  @override
  void didPop() {
    // 이 화면에서 나갔을 때
    debugPrint('🛑 NavigationPage 화면 나감 (didPop) - 자동 측정 저장');
    _saveAutoMeasurement();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    final bool isKeyboardNowVisible = bottomInset > 0.0;

    if (_isKeyboardVisible != isKeyboardNowVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardNowVisible;
        // debugPrint('⌨️ 키보드 상태 변경: $_isKeyboardVisible');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 앱이 백그라운드로 이동 - 자동 측정 저장');
        _saveAutoMeasurement();
        break;
      case AppLifecycleState.resumed:
        debugPrint('📱 앱이 포그라운드로 복원 - 자동 측정 시작');
        _startAutoMeasurement();
        break;
      case AppLifecycleState.detached:
        _saveAutoMeasurement();
        _stopRouteGuiding();
        break;
      default:
        break;
    }
  }

  // ==================== 자동 측정 관련 함수들 ====================

  /// 🆕 자동 측정 시작
  void _startAutoMeasurement() {
    if (!_isAutoMeasuring) {
      _isAutoMeasuring = true;
      _autoStartTime = DateTime.now();
      _autoTotalDistance = 0.0;
      _autoMaxSpeed = 0.0;
      _autoSpeedHistory.clear();
      _autoLastPosition = _state.currentPosition;

      // debugPrint('🚗 자동 주행 측정 시작!');

      // 실시간 시간 업데이트 타이머 시작
      _startTimeUpdateTimer();

      if (mounted) {
        _showSnackBarSafe(SnackBar(
          content: Row(
            children: [
              Icon(Icons.directions_car, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('주행 측정이 자동으로 시작되었습니다'),
            ],
          ),
          backgroundColor: Colors.teal[100],
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// 🆕 자동 측정 저장
  void _saveAutoMeasurement() {
    if (_isAutoMeasuring && _autoStartTime != null) {
      // debugPrint('💾 자동 주행 기록 저장!');

      // 주행 로그 저장
      _saveAutoMeasurementLog();

      // 🆕 실시간 시간 업데이트 타이머 정리
      _stopTimeUpdateTimer();

      // 상태 초기화
      _isAutoMeasuring = false;

      final distance = _formatDistance(_autoTotalDistance);

      // 사용자에게 알림
      if (mounted) {
        _showSnackBarSafe(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.save, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('주행 기록이 자동으로 저장되었습니다 ($distance)'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// 🆕 자동 측정 로그 저장
  Future<void> _saveAutoMeasurementLog() async {
    if (_autoStartTime == null) return;

    // 평균 속도 계산
    double averageSpeed = 0.0;
    if (_autoSpeedHistory.isNotEmpty) {
      double totalSpeed = _autoSpeedHistory.reduce((a, b) => a + b);
      averageSpeed = totalSpeed / _autoSpeedHistory.length;
    }

    DrivingData drivingData = DrivingData(
      startTime: _autoStartTime!,
      endTime: DateTime.now(),
      totalDistance: _autoTotalDistance,
      averageSpeed: averageSpeed,
      maxSpeed: _autoMaxSpeed,
      destination: _state.hasDestination ? _state.destination : '목적지 없음',
      destinationLat: _state.destinationLat,
      destinationLng: _state.destinationLng,
      reachedDestination: false, // 자동 측정에서는 도착 판정 안함
    );

    final drivingLogService = ref.read(drivingLogServiceProvider);
    await drivingLogService.saveDrivingLog(drivingData);
  }

  /// 자동 측정 주행거리 업데이트
  void _updateAutoMeasurement(Position position) {
    if (!_isAutoMeasuring || _autoLastPosition == null) return;

    double distance = LocationService.calculateDistanceRobust(
      _autoLastPosition!,
      position,
    );

    if (distance > 0) {
      setState(() {
        _autoTotalDistance += distance;
        _autoLastPosition = position;
      });
      debugPrint('📏 자동 측정 거리 누적: +${distance.toStringAsFixed(1)}m, 총: ${_autoTotalDistance.toStringAsFixed(1)}m');
    }
  }

  /// 🆕 자동 측정 속도 업데이트
  void _updateAutoSpeed(Position position) {
    if (!_isAutoMeasuring) return;

    double speedKmh = LocationService.convertSpeedToKmh(position.speed);

    if (speedKmh <= 5.0) {
      speedKmh = 0.0;
    }

    setState(() {
      _autoSpeedHistory.add(speedKmh);
      if (speedKmh > _autoMaxSpeed) {
        _autoMaxSpeed = speedKmh;
      }
    });
  }

  // ==================== 🆕 실시간 시간 업데이트 관련 함수들 ====================

  /// 🆕 실시간 시간 업데이트 타이머 시작
  void _startTimeUpdateTimer() {
    _timeUpdateTimer?.cancel(); // 기존 타이머가 있으면 취소

    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isAutoMeasuring && mounted) {
        setState(() {
          // 1초마다 UI 업데이트 (시간 표시를 위해)
          // debugPrint('⏰ 실시간 시간 업데이트: ${_formattedAutoDrivingTime}');
        });
      }
    });
    //
    // debugPrint('⏰ 실시간 시간 업데이트 타이머 시작');
  }

  /// 🆕 실시간 시간 업데이트 타이머 정지
  void _stopTimeUpdateTimer() {
    _timeUpdateTimer?.cancel();
    _timeUpdateTimer = null;
    // debugPrint('⏰ 실시간 시간 업데이트 타이머 정지');
  }

  // ==================== 경로 안내 관련 함수들 ====================

  /// 🆕 경로 안내 시작
  void _startRouteGuiding() {
    LocationService.resetSpeedFilter();

    setState(() {
      _isRouteGuiding = true;
      // 경로 시작 시간 기록 (버튼 클릭 시점)
      _routeStartTime = DateTime.now();
    });

    // 경로 안내 시작할 때도 실시간 시간 업데이트 시작
    if (_isAutoMeasuring) {
      _startTimeUpdateTimer();
    }

    if (_state.currentPosition != null) {
      _updateMapLocation(_state.currentPosition!);
    }

    if (_state.hasDestination) {
      _startRouteRecalculationTimer();
    }

    // debugPrint('🚗 경로 시작 - _isRouteGuiding: $_isRouteGuiding, 시작시간: $_routeStartTime');
  }

  /// 경로 안내 종료
  void _stopRouteGuiding() {
    if (!_isRouteGuiding) return;

    //  경로 초기화 전에 목적지 여부를 미리 저장
    final bool hadDestination = _state.hasDestination;

    setState(() {
      _isRouteGuiding = false;
      //  경로 시간 초기화
      _routeStartTime = null;
    });

    //  경로 안내 종료할 때는 시간 업데이트 타이머만 정지 (자동 측정은 계속)
    _stopTimeUpdateTimer();

    _stopRouteRecalculationTimer();
    _clearRoute();

    if (mounted) {
      _showSnackBarSafe(SnackBar(
        content: Row(
          children: [
            Icon(
                hadDestination ? Icons.navigation_outlined : Icons.directions_car,
                color: Colors.white,
                size: 16
            ),
            SizedBox(width: 8),
            Text(hadDestination ? '경로 안내가 종료되었습니다.' : '안전 운전이 종료되었습니다.'),
          ],
        ),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }

    // debugPrint('🛑 경로/안전 운전 종료 - _isRouteGuiding: $_isRouteGuiding');
  }

  // ==================== 초기화 함수들 ====================

  Future<void> _initializeLocation() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
    _setupLocationStream();
  }

  Future<void> _checkLocationPermission() async {
    bool hasPermission = await LocationService.checkLocationPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다.')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    Position? position = await LocationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _state.currentPosition = position;
        _state.lastPosition = position;
        _autoLastPosition = position; // 자동 측정용 위치도 초기화
      });
      _updateMapLocation(position);
    }
  }

  void _setupLocationStream() {
    debugPrint('📍 위치 스트림 구독 시작...');

    _locationSubscription?.cancel();

    _locationSubscription = LocationService.getLocationStream().listen(
          (position) {
        debugPrint('📍 위치 업데이트: ${position.latitude}, ${position.longitude}');
        _updateLocation(position);
      },
      onError: (error) {
        debugPrint('❌ 위치 스트림 오류: $error');
      },
      onDone: () {
        debugPrint('📍 위치 스트림 종료됨');
      },
    );
  }

  // ==================== 위치 업데이트 함수들 ====================

  void _updateLocation(Position position) {
    setState(() {
      _state.lastPosition = _state.currentPosition;
      _state.currentPosition = position;
    });

    _updateSpeed(position);
    _updateAutoMeasurement(position);      // 🆕 자동 측정 업데이트
    _updateAutoSpeed(position);            // 🆕 자동 측정 속도 업데이트
    _updateDistanceToDestination();
    _updateMapLocation(position);

    // 경로 이탈 감지 (안전 운전 중이고 목적지가 있을 때만)
    if (_isRouteGuiding && _state.hasDestination) {
      _checkRouteDeviation();
    }
  }

  void _updateSpeed(Position position) {
    double speedKmh = LocationService.convertSpeedToKmh(position.speed);

    if (speedKmh <= 5.0) {
      speedKmh = 0.0;
    }

    setState(() {
      _state.currentSpeed = speedKmh;
    });

    final isDriving = speedKmh > 5.0;

    // 🆕 첫 번째 위치 업데이트에서 Redis 초기화
    if (!_hasInitializedDrivingStatus) {
      _hasInitializedDrivingStatus = true;
      _lastDrivingStatus = false; // 초기값 설정
      debugPrint('[초기화] Redis 주행 상태를 false로 초기화');
      _updateDrivingStatus(false); // 명시적으로 false로 초기화
      return; // 첫 번째는 초기화만 하고 상태 변경 감지는 스킵
    }

    // 🆕 더 상세한 로그 추가
    debugPrint('[속도 체크] 현재속도: ${speedKmh.toStringAsFixed(1)}km/h, isDriving: $isDriving, 이전상태: $_lastDrivingStatus');

    if (_lastDrivingStatus != isDriving) {
      _lastDrivingStatus = isDriving;
      debugPrint('[상태 변경] 주행 상태가 변경되었습니다: $_lastDrivingStatus → $isDriving');
      _updateDrivingStatus(isDriving);
    } else {
      debugPrint('[상태 유지] 주행 상태 변경 없음: $isDriving');
    }
  }

  void _updateDistanceToDestination() {
    if (!_state.hasDestination || _state.currentPosition == null) return;

    double fallback = LocationService.calculateDistance(
      _state.currentPosition!.latitude,
      _state.currentPosition!.longitude,
      _state.destinationLat,
      _state.destinationLng,
    );

    final remaining = LocationService.calculateRemainingRouteDistance(
      currentPosition: _state.currentPosition,
      routeCoordinates: _state.routeCoordinates,
      fallbackDistance: fallback,
    );

    setState(() {
      _state.distanceToDestination = remaining;
    });
  }

  // 운전 상태 API 갱신 함수 - 더 깔끔한 버전
  Future<void> _updateDrivingStatus(bool isDriving) async {
    try {
      final dio = ref.read(authDioProvider);
      final vin = ref.read(currentVinProvider);
      if (vin == null) {
        debugPrint('[DrivingStatus] VIN이 없습니다');
        return;
      }

      // debugPrint('[DrivingStatus] API 호출 시작 - VIN: $vin, isDriving: $isDriving');

      // 🆕 queryParameters 사용 (더 깔끔함)
      final response = await dio.patch(
        '/api/v1/cars/$vin/driving-status',
        queryParameters: {
          'isDriving': isDriving,
        },
        options: Options(
          headers: {'accept': '*/*'},
        ),
      );

      debugPrint('[DrivingStatus] API 응답 성공 - Status: ${response.statusCode}');

    } catch (e) {
      if (e is DioException) {
        debugPrint('[DrivingStatus] API 호출 실패:');
        debugPrint('  - 상태 코드: ${e.response?.statusCode}');
        debugPrint('  - 응답 메시지: ${e.response?.data}');
      } else {
        debugPrint('[DrivingStatus] 네트워크 에러: $e');
      }
    }
  }

  // ==================== 지도 업데이트 ====================

  Future<void> _updateMapLocation(Position position) async {
    if (_state.mapController == null || !_state.isMapReady) return;

    final now = DateTime.now();
    if (_lastCameraMoveAt != null &&
        now.difference(_lastCameraMoveAt!) < _minCameraUpdateGap) {
      return;
    }
    _lastCameraMoveAt = now;

    final targetBearing = _followHeading ? _computeHeadingDeg(position) : 0.0;
    _smoothedBearingDeg = _smoothAngle(_smoothedBearingDeg, targetBearing, 0.25);

    final target = LatLng(position.latitude, position.longitude);
    final tilt = _followHeading ? 50.0 : 0.0;

    await _state.mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: _lastZoom,
          tilt: tilt,
          bearing: _smoothedBearingDeg,
        ),
      ),
    );
  }

  // ==================== 검색 관련 함수들 ====================

  Future<void> _searchDestination() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _state.isSearching = true;
    });

    try {
      List<Map<String, dynamic>> results = await KakaoApiService.searchAddress(
        _searchController.text.trim(),
      );

      setState(() {
        _state.searchResults = results;
        _state.isSearching = false;
      });

      if (mounted) {
        _showSearchResultsDialog();
      }
    } catch (e) {
      setState(() {
        _state.isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e')),
        );
      }
    }
  }

  void _showSearchResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => SearchResultsDialog(
        results: _state.searchResults,
        onSelect: _selectDestination,
      ),
    );
  }

  void _selectDestination(Map<String, dynamic> result) {
    FocusScope.of(context).unfocus();

    setState(() {
      _state.destination = result['address'];
      _state.destinationLat = result['latitude'];
      _state.destinationLng = result['longitude'];
      _state.hasDestination = true;
    });

    _searchController.clear();
    _addDestinationMarker();
    _calculateRoute();
  }

  // ==================== 경로 관련 함수들 ====================

  Future<void> _calculateRoute() async {
    if (!_state.hasDestination || _state.currentPosition == null) return;

    setState(() {
      _state.isCalculatingRoute = true;
    });

    try {
      Map<String, dynamic> routeData = await KakaoApiService.getRoute(
        _state.currentPosition!.latitude,
        _state.currentPosition!.longitude,
        _state.destinationLat,
        _state.destinationLng,
      );

      setState(() {
        _state.routeCoordinates = List<Map<String, double>>.from(routeData['coordinates']);
        _state.estimatedTime = _formatDuration(routeData['duration']);
        _state.estimatedDistance = _formatDistance(routeData['distance']);
        _state.trafficInfo = routeData['traffic'];
        _state.routeDistance = routeData['distance'].toDouble();
        _state.isCalculatingRoute = false;
      });

      _drawRouteOnMap();
      _startRouteRecalculationTimer();
    } catch (e) {
      setState(() {
        _state.isCalculatingRoute = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('경로 계산 실패: $e')),
        );
      }
    }
  }

  void _drawRouteOnMap() {
    if (_state.routeCoordinates.isEmpty) return;

    List<LatLng> points = _state.routeCoordinates.map((coord) {
      return LatLng(coord['latitude']!, coord['longitude']!);
    }).toList();

    setState(() {
      _state.polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      };
    });
  }

  void _addDestinationMarker() {
    setState(() {
      _state.markers = {
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_state.destinationLat, _state.destinationLng),
          infoWindow: InfoWindow(title: _state.destination),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _startRouteRecalculationTimer() {
    _routeRecalculationTimer?.cancel();
    _routeRecalculationTimer = Timer.periodic(_routeRecalculationInterval, (timer) {
      if (_isRouteGuiding && _state.hasDestination) {
        _calculateRoute();
      }
    });
  }

  void _stopRouteRecalculationTimer() {
    _routeRecalculationTimer?.cancel();
  }

  void _clearRoute() {
    setState(() {
      _state.routeCoordinates.clear();
      _state.polylines.clear();
      _state.markers.clear();
      _state.destination = '';
      _state.hasDestination = false;
      _state.estimatedTime = '';
      _state.estimatedDistance = '';
      _state.trafficInfo = '';
      _state.routeDistance = 0.0;
      _state.distanceToDestination = 0.0;
    });

    _stopRouteRecalculationTimer();
  }

  // ==================== 경로 이탈 감지 ====================

  static const double _routeDeviationThreshold = 20.0;
  static const Duration _recalculationCooldown = Duration(seconds: 10);
  DateTime? _lastRecalculationTime;
  bool _isRecalculatingRoute = false;

  void _checkRouteDeviation() {
    if (_state.routeCoordinates.isEmpty ||
        _state.currentPosition == null ||
        _isRecalculatingRoute) return;

    if (_lastRecalculationTime != null) {
      final timeSinceLastRecalculation = DateTime.now().difference(_lastRecalculationTime!);
      if (timeSinceLastRecalculation < _recalculationCooldown) {
        return;
      }
    }

    double distanceToRoute = _calculateDistanceToRoute();

    final dynamicThreshold = math.max(
      _routeDeviationThreshold,
      (_state.currentPosition?.accuracy ?? 0) * 1.5,
    );

    // debugPrint('📍 경로와의 거리: ${distanceToRoute.toStringAsFixed(1)}m');

    if (distanceToRoute > _routeDeviationThreshold) {
      // debugPrint('🚨 경로 이탈 감지! ${distanceToRoute.toStringAsFixed(1)}m > ${_routeDeviationThreshold}m');
      _handleRouteDeviation();
    }
  }

  double _calculateDistanceToRoute() {
    if (_state.routeCoordinates.isEmpty || _state.currentPosition == null) {
      return 0.0;
    }

    return LocationService.calculateDistanceToRouteLine(
      currentPosition: _state.currentPosition!,
      routeCoordinates: _state.routeCoordinates,
    );
  }

  void _handleRouteDeviation() {
    _isRecalculatingRoute = true;
    _lastRecalculationTime = DateTime.now();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text('경로를 벗어났습니다. 재계산 중...'),
            ],
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _recalculateRouteAfterDeviation();
  }

  Future<void> _recalculateRouteAfterDeviation() async {
    try {
      await _calculateRoute();

      // debugPrint('✅ 경로 재계산 완료');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 12),
                const Text('새로운 경로로 안내합니다'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 경로 재계산 실패: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 16),
                const SizedBox(width: 12),
                const Text('경로 재계산에 실패했습니다'),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isRecalculatingRoute = false;
    }
  }

  // ==================== 카메라 방향 ====================

  bool _followHeading = true;
  double _compassHeadingDeg = 0;
  double _smoothedBearingDeg = 0;
  StreamSubscription<CompassEvent>? _compassSub;
  double _lastZoom = 18.0;

  DateTime? _lastCameraMoveAt;
  static const _minCameraUpdateGap = Duration(milliseconds: 700);

  double _computeHeadingDeg(Position p) {
    final mps = (p.speed.isFinite ? p.speed : 0.0);
    final gpsHeading = (p.heading.isFinite && p.heading >= 0) ? p.heading : double.nan;

    if (mps > 1.4 && gpsHeading.isFinite) {
      return gpsHeading % 360;
    }
    return _compassHeadingDeg;
  }

  double _smoothAngle(double fromDeg, double toDeg, double factor) {
    final delta = ((toDeg - fromDeg + 540) % 360) - 180;
    return (fromDeg + delta * factor + 360) % 360;
  }

  // ==================== 내 위치 이동 ====================

  void _moveToMyLocation() async {
    debugPrint('📍 내 위치로 이동 시작...');

    try {
      Position? position = await LocationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _state.currentPosition = position;
        });

        if (_state.mapController != null && _state.isMapReady) {
          await _state.mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 16.0,
                tilt: 0.0,
                bearing: 0.0,
              ),
            ),
          );

          debugPrint('📍 지도 이동 완료');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('내 위치로 이동했습니다'),
                duration: const Duration(seconds: 1),
                backgroundColor: Colors.teal[100],
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception('지도가 준비되지 않았습니다');
        }
      } else {
        throw Exception('현재 위치를 가져올 수 없습니다');
      }
    } catch (e) {
      debugPrint('❌ 내 위치 이동 실패: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 이동 실패: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==================== 유틸리티 함수들 ====================

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes분 $remainingSeconds초';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  // 🆕 자동 측정 데이터를 위한 포맷팅 함수들
  String get _formattedAutoDistance {
    return _formatDistance(_autoTotalDistance);
  }

  String get _formattedAutoDrivingTime {
    if (_autoStartTime == null) return '0분 0초';
    final duration = DateTime.now().difference(_autoStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes분 $seconds초';
  }

  // 🆕 경로 시작 시간 포맷팅 (목적지가 있을 때 사용)
  String get _formattedRouteTime {
    if (_routeStartTime == null) return '0분 0초';
    final duration = DateTime.now().difference(_routeStartTime!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes분 $seconds초';
  }

  // 🆕 표시할 시간 결정 (목적지 여부에 따라)
  String get _formattedDisplayTime {
    if (_state.hasDestination && _routeStartTime != null) {
      return _formattedRouteTime; // 목적지 있으면 경로 시간
    } else {
      return _formattedAutoDrivingTime; // 목적지 없으면 자동 측정 시간
    }
  }

  // 🆕 시간 라벨 결정 (목적지 여부에 따라)
  String get _timeLabel {
    return _state.hasDestination ? '경로시간' : '자동측정';
  }

  String get _formattedRemainingDistance {
    if (!_state.hasDestination) return '-';
    return _formatDistance(_state.distanceToDestination);
  }

  // 🆕 버튼 텍스트 결정 (목적지 여부에 따라)
  String get _buttonText {
    if (_isRouteGuiding) {
      return _state.hasDestination ? '경로 종료' : '운전 종료';
    } else {
      return _state.hasDestination ? '경로 시작' : '안전 운전';
    }
  }

  // ==================== UI 빌드 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Navigation',
        onBackButtonPressed: () => Navigator.pop(context),
      ),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Google Maps
          MediaQuery.removeViewInsets(
            context: context,
            removeLeft: true,
            removeTop: true,
            removeRight: true,
            removeBottom: true,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _state.currentPosition != null
                    ? LatLng(_state.currentPosition!.latitude, _state.currentPosition!.longitude)
                    : const LatLng(37.5665, 126.9780), // 서울 시청
                zoom: 15,
              ),
              onMapCreated: (controller) {
                setState(() {
                  _state.mapController = controller;
                  _state.isMapReady = true;
                });
              },
              markers: _state.markers,
              polylines: _state.polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              padding: EdgeInsets.zero,
              onCameraMove: (camPos) {
                _lastZoom = camPos.zoom;
              },
              rotateGesturesEnabled: true,
            ),
          ),

          // 속도 오버레이 - 항상 표시
          SpeedOverlay(
            currentSpeed: _state.formattedCurrentSpeed,
            isDriving: true, // 🆕 항상 속도 표시
          ),

          // 검색바 - 안전 운전 중이 아닐 때만 표시
          if (!_isRouteGuiding)
            DestinationSearchBar(
              controller: _searchController,
              onSearch: _searchDestination,
              isSearching: _state.isSearching,
            ),

          // 목적지 정보
          DestinationInfo(
            destination: _state.destination,
            estimatedTime: _state.estimatedTime,
            estimatedDistance: _state.estimatedDistance,
            trafficInfo: _state.trafficInfo,
            onClear: _clearRoute,
            isDriving: _isRouteGuiding, // 🆕 안전 운전 상태로 변경
          ),

          // 내 위치 버튼 - 항상 표시
          if (!_isKeyboardVisible)
            MyLocationButton(
              onPressed: _moveToMyLocation,
              isDriving: _isRouteGuiding, // 🆕 안전 운전 상태에 따라 위치 조정
            ),

          // 🆕 운전 컨트롤 - 안전 운전 중일 때만 주행정보 표시
          if (!_isKeyboardVisible)
            DrivingControls(
              hasAuto: _isAutoMeasuring, // 자동 측정 상태
              isDriving: _isRouteGuiding, // 안전 운전 상태
              onStartDriving: _startRouteGuiding, // 안전 운전 시작
              onStopDriving: _stopRouteGuiding,   // 안전 운전 종료
              totalDistance: _isRouteGuiding ? _formattedAutoDistance : '0m', // 🆕 안전 운전 중일 때만 거리 표시
              drivingTime: _isRouteGuiding ? _formattedDisplayTime : '0분 0초', // 🆕 목적지 여부에 따른 시간 표시
              remainingDistance: _formattedRemainingDistance, // 남은 거리
              timeLabel: _timeLabel, // 🆕 시간 라벨 전달
              buttonText: _buttonText, // 🆕 버튼 텍스트 전달
              hasDestination: _state.hasDestination, // 🆕 목적지 여부 전달
            ),

          // 로딩 인디케이터
          if (_state.isCalculatingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // 헤딩 따라가기 토글
          if (!_isKeyboardVisible)
            HeadingFollowButton(
              enabled: _followHeading,
              onPressed: () {
                setState(() {
                  _followHeading = !_followHeading;
                  if (!_followHeading) {
                    _smoothedBearingDeg = 0;
                  } else if (_state.currentPosition != null) {
                    _smoothedBearingDeg = _computeHeadingDeg(_state.currentPosition!);
                  }
                });
              },
            ),
          const VoiceAssistantPanel(
            autoStart: true,
            showBadge: true,
            requireWakeWord: true,
            showDebugPanel: true, // 디버그 카드 보고 싶다면 true
          ),
          // ⬇️ SSE 모달 오버레이 (LLM/음성 없음)
          const SSEAlertOverlay(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: VoiceAssistantPanel(
                showDebugPanel: false,   // 필요 시 true로 바꿔 디버그 카드 확인
                autoStart: true,         // 네비 켜지면 자동 활성화
                requireWakeWord: true,   // "모링아..."로 깨우기 (false면 항상 대기)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
