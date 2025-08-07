import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'dart:async';

// 서비스들
import 'services/kakao_api_service.dart';
import 'services/location_service.dart';
import 'services/driving_log_service.dart';

// 모델들
import 'models/navigation_state.dart';
import 'models/driving_data.dart';

// 위젯들
import 'widgets/speed_overlay.dart';
import 'widgets/search_bar.dart';
import 'widgets/destination_info.dart';
import 'widgets/driving_controls.dart';
import 'widgets/search_results_dialog.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({Key? key}) : super(key: key);

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> with WidgetsBindingObserver {
  // 네비게이션 상태
  final NavigationState _state = NavigationState();
  
  // 검색 관련
  final TextEditingController _searchController = TextEditingController();
  
  // 자동 경로 재계산 관련
  Timer? _routeRecalculationTimer;
  static const Duration _routeRecalculationInterval = Duration(minutes: 2);
  
  // 위치 스트림 구독
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _routeRecalculationTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.detached:
        _stopDriving();
        break;
      default:
        break;
    }
  }

  // ==================== 초기화 함수들 ====================
  
  /// 위치 초기화
  Future<void> _initializeLocation() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
    _setupLocationStream();
  }
  
  /// 위치 권한 확인
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
  
  /// 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    Position? position = await LocationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _state.currentPosition = position;
        _state.lastPosition = position;
      });
      _updateMapLocation(position);
    }
  }
  
  /// 위치 스트림 설정
  void _setupLocationStream() {
    _locationSubscription = LocationService.getLocationStream().listen(
      (position) => _updateLocation(position),
      onError: (error) {
        print('❌ 위치 스트림 오류: $error');
      },
    );
  }

  // ==================== 위치 업데이트 함수들 ====================
  
  /// 위치 업데이트 메인 함수
  void _updateLocation(Position position) {
    setState(() {
      _state.lastPosition = _state.currentPosition;
      _state.currentPosition = position;
    });
    
    _updateSpeed(position);
    _updateDrivingDistance(position);
    _updateDistanceToDestination();
    _updateMapLocation(position);
  }
  
  /// 속도 업데이트
  void _updateSpeed(Position position) {
    double speedKmh = LocationService.convertSpeedToKmh(position.speed);
    double filteredSpeed = LocationService.filterSpeed(_state.speedBuffer, speedKmh);
    
    setState(() {
      _state.currentSpeed = filteredSpeed.toStringAsFixed(0);
      
      if (_state.isDriving) {
        _state.speedHistory.add(filteredSpeed);
        if (filteredSpeed > _state.maxSpeed) {
          _state.maxSpeed = filteredSpeed;
        }
      }
    });
  }
  
  /// 주행 거리 업데이트
  void _updateDrivingDistance(Position position) {
    if (!_state.isDriving || _state.lastPosition == null) return;
    
    double distance = LocationService.calculateDistance(
      _state.lastPosition!.latitude,
      _state.lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    setState(() {
      _state.totalDrivingDistance += distance;
    });
    
    // 목적지 도착 확인
    if (_state.hasDestination) {
      _checkDestinationArrival();
    }
  }
  
  /// 목적지까지의 거리 업데이트
  void _updateDistanceToDestination() {
    if (!_state.hasDestination || _state.currentPosition == null) return;
    
    double distance = LocationService.calculateDistance(
      _state.currentPosition!.latitude,
      _state.currentPosition!.longitude,
      _state.destinationLat,
      _state.destinationLng,
    );
    
    setState(() {
      _state.distanceToDestination = distance;
    });
  }
  
  /// 지도 위치 업데이트
  void _updateMapLocation(Position position) {
    if (_state.mapController != null && _state.isMapReady) {
      _state.mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }
  }

  // ==================== 검색 관련 함수들 ====================
  
  /// 목적지 검색
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
  
  /// 검색 결과 다이얼로그 표시
  void _showSearchResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => SearchResultsDialog(
        results: _state.searchResults,
        onSelect: _selectDestination,
      ),
    );
  }
  
  /// 목적지 선택
  void _selectDestination(Map<String, dynamic> result) {
    setState(() {
      _state.destination = result['address'];
      _state.destinationLat = result['latitude'];
      _state.destinationLng = result['longitude'];
      _state.hasDestination = true;
    });
    
    _addDestinationMarker();
    _calculateRoute();
  }

  // ==================== 경로 관련 함수들 ====================
  
  /// 경로 계산
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
  
  /// 지도에 경로 그리기
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
  
  /// 목적지 마커 추가
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
  
  /// 경로 재계산 타이머 시작
  void _startRouteRecalculationTimer() {
    _routeRecalculationTimer?.cancel();
    _routeRecalculationTimer = Timer.periodic(_routeRecalculationInterval, (timer) {
      if (_state.isDriving && _state.hasDestination) {
        _calculateRoute();
      }
    });
  }
  
  /// 경로 재계산 타이머 정지
  void _stopRouteRecalculationTimer() {
    _routeRecalculationTimer?.cancel();
  }
  
  /// 경로 초기화
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

  // ==================== 주행 관련 함수들 ====================
  
  /// 운전 시작
  void _startDriving() {
    setState(() {
      _state.isDriving = true;
      _state.drivingStartTime = DateTime.now();
      _state.totalDrivingDistance = 0.0;
      _state.maxSpeed = 0.0;
      _state.speedHistory.clear();
    });
    
    if (_state.hasDestination) {
      _startRouteRecalculationTimer();
    }
  }
  
  /// 운전 종료
  void _stopDriving() {
    if (!_state.isDriving) return;
    
    setState(() {
      _state.isDriving = false;
    });
    
    _stopRouteRecalculationTimer();
    _saveDrivingLog();
  }
  
  /// 주행 로그 저장
  Future<void> _saveDrivingLog() async {
    if (_state.drivingStartTime == null) return;
    
    DrivingData drivingData = DrivingData(
      startTime: _state.drivingStartTime!,
      endTime: DateTime.now(),
      totalDistance: _state.totalDrivingDistance,
      averageSpeed: _state.averageSpeed,
      maxSpeed: _state.maxSpeed,
      destination: _state.destination,
      destinationLat: _state.destinationLat,
      destinationLng: _state.destinationLng,
      reachedDestination: _state.distanceToDestination <= 30,
    );
    
    await DrivingLogService.saveDrivingLog(drivingData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주행 로그 저장 완료: ${drivingData.formattedDistance}')),
      );
    }
  }
  
  /// 목적지 도착 확인
  void _checkDestinationArrival() {
    if (_state.distanceToDestination <= 30) {
      _onDestinationReached();
    }
  }
  
  /// 목적지 도착 처리
  void _onDestinationReached() {
    _clearRoute();
    _stopRouteRecalculationTimer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목적지에 도착했습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==================== 유틸리티 함수들 ====================
  
  /// 시간 포맷팅 (초 -> 분:초)
  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}분 ${remainingSeconds}초';
  }
  
  /// 거리 포맷팅 (미터 -> km)
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
  
  /// 다크 테마 지도 스타일
  String _getDarkMapStyle() {
    return '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      }
    ]
    ''';
  }

  // ==================== UI 빌드 ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Maps
          GoogleMap(
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
              // 다크 스타일 제거 - 기본 지도 스타일 사용
              // controller.setMapStyle(_getDarkMapStyle());
            },
            markers: _state.markers,
            polylines: _state.polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // 속도 오버레이
          SpeedOverlay(
            currentSpeed: _state.formattedCurrentSpeed,
            isDriving: _state.isDriving,
          ),
          
          // 검색바
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
          ),
          
          // 운전 컨트롤
          DrivingControls(
            isDriving: _state.isDriving,
            onStartDriving: _startDriving,
            onStopDriving: _stopDriving,
            totalDistance: _state.formattedTotalDistance,
            drivingTime: _state.formattedDrivingTime,
          ),
          
          // 로딩 인디케이터
          if (_state.isCalculatingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
