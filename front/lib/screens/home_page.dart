import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스 임포트
import 'package:moring/utils/bottom_nav_bar.dart'; // CustomBottomNavBar 위젯 임포트
import 'package:moring/utils/custom_app_bar.dart'; // CustomAppBar 위젯 임포트
import 'package:moring/models/consumable.dart'; // Consumable 모델 임포트
import 'package:moring/widgets/car_360_viewer.dart';
import 'package:moring/models/vehicle.dart'; // Vehicle 모델 임포트

import '../providers/token_repository.dart';

class HomePage extends ConsumerStatefulWidget  {
  // 🔑 vehicle 필드를 optional하게 선언합니다.
  final Vehicle? vehicle;

  // 🔑 생성자도 vehicle을 optional로 받도록 수정합니다.
  const HomePage({super.key, this.vehicle});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0; // 하단 네비게이션 바 선택 인덱스
  late List<Consumable> consumables;

  List<String> _currentCarImagePaths = [];
  String _selectedCar = 'xm3'; // 현재 선택된 차량 (초기값)
  final List<String> _availableCars = ['xm3', '그렌저', '재규어'];


  @override
  void initState() {
    super.initState();
    // 초기 소모품 데이터 설정
    consumables = [
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Engine Oil',
        lastReplacedDate: DateTime(2025, 5, 15),
        replacementCycleMonths: 8,
      ),
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Oil Filter',
        lastReplacedDate: DateTime(2025, 3, 1),
        replacementCycleMonths: 12,
      ),
      Consumable(
        icon: AppIcons.airFilter,
        title: 'Air Filter',
        lastReplacedDate: DateTime(2025, 1, 10),
        replacementCycleMonths: 8,
      ),
    ];

    // 🔑 vehicle 인자가 존재하면 해당 차량의 이미지로 초기화합니다.
    if (widget.vehicle != null) {
      _setCarImages(widget.vehicle!.modelName);
    } else {
      // 인자가 없으면 기존처럼 'xm3'로 초기화
      _setCarImages(_selectedCar);
    }
  }

  // 차량 이미지를 동적으로 설정하는 함수
  void _setCarImages(String carName) {
    setState(() {
      _selectedCar = carName; // 선택된 차량 업데이트
      int numImages;
      String basePath;

      switch (carName) {
        case 'xm3':
          numImages = 36;
          basePath = 'assets/xm3/xm3_';
          break;
        case '그렌저':
          numImages = 36;
          basePath = 'assets/그렌저/';
          break;
        case '재규어':
          numImages = 30;
          basePath = 'assets/재규어/';
          break;
        default:
          numImages = 0;
          basePath = '';
          break;
      }

      _currentCarImagePaths = List.generate(
        numImages,
            (index) {
          return '$basePath${index + 1}.png';
        },
      );
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // 🔑 하단바 탭 시 페이지 전환 로직은 여기에 구현합니다.
    // 기존의 HomePage를 다시 호출하는 불필요한 로직은 제거했습니다.
    // 예시:
    // if (index == 0) {
    //   // Home 화면 (현재 화면이므로 특별한 동작 없음)
    // } else if (index == 1) {
    //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NavigationPage()));
    // }
  }

  Future<void> _logout() async {
    print('로그아웃 시작');
    final repo = ref.read(tokenRepositoryProvider);
    final refreshToken = await repo.getRefreshToken();

    final cookieHeader = 'refreshToken=$refreshToken';
    final dio = ref.read(noAuthDioProvider);
    final resp = await dio.post(
      '/api/v1/auth/logout/rToken',
      options: Options(headers: {
        'Cookie': cookieHeader,
      },
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    if (resp.statusCode == 200) {
      await repo.deleteAllTokens();
      Navigator.pushReplacementNamed(context, '/login');
    } else if(resp.statusCode == 302){
      print('로그아웃 302');
      await repo.deleteAllTokens();

      final refreshToken = await repo.getRefreshToken();

      debugPrint('▶︎ refreshToken = $refreshToken');

      Navigator.pushReplacementNamed(context, '/login');
    } else {
      print('로그아웃 실패');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        // 🔑 vehicle 인자가 있으면 닉네임, 없으면 'Moring'으로 표시
        title: widget.vehicle?.nickname ?? 'Moring',
        onBackButtonPressed: () {
          Navigator.pop(context);
        },
        showCarDropdown: true,
        availableCars: _availableCars,
        selectedCar: _selectedCar,
        onCarChanged: (newValue) {
          if (newValue != null) {
            _setCarImages(newValue);
          }
        },
        onNotificationPressed: () async{
          final repo = ref.read(tokenRepositoryProvider);
          final accessToken = await repo.getAccessToken();
          final refreshToken = await repo.getRefreshToken();
          debugPrint('▶︎ accessToken = $accessToken');
          debugPrint('▶︎ refreshToken = $refreshToken');
          await _logout();
          print('알림 버튼 클릭!');
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[900],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Car360Viewer(
                    imagePaths: _currentCarImagePaths,
                    sensitivity: 10.0,
                    width: double.infinity,
                    height: 250,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '소모품 현황',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...consumables.map((consumable) {
                final nextReplacementDate = consumable.getNextReplacementDate();
                final formattedDate = '${nextReplacementDate.year}-${nextReplacementDate.month.toString().padLeft(2, '0')}-${nextReplacementDate.day.toString().padLeft(2, '0')}';

                return Column(
                  children: [
                    _buildConsumableStatusCard(
                      context: context,
                      icon: consumable.icon,
                      title: consumable.title,
                      date: '다음 교체: $formattedDate',
                      progress: consumable.getRemainingPercentage(),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }).toList(),
              const SizedBox(height: 20),
              _buildDrivingLogSection(
                context: context,
                title: 'Today',
                logs: [
                  {'distance': '15.2 mi', 'time': '12:30 PM - 1:00 PM'},
                ],
              ),
              const SizedBox(height: 20),
              _buildDrivingLogSection(
                context: context,
                title: 'Yesterday',
                logs: [
                  {'distance': '22.5 mi', 'time': '9:00 AM - 9:45 AM'},
                  {'distance': '5.0 mi', 'time': '5:30 PM - 5:45 PM'},
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildConsumableStatusCard({
    required BuildContext context,
    required Icon icon,
    required String title,
    required String date,
    required double progress,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.7 ? Colors.greenAccent : (progress > 0.3 ? Colors.amberAccent : Colors.redAccent),
                ),
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivingLogSection({
    required BuildContext context,
    required String title,
    required List<Map<String, String>> logs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: logs.map((log) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: AppIcons.loccation,
                  title: Text(
                    log['distance']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  subtitle: Text(
                    log['time']!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  onTap: () {
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}