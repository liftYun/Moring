import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/models/consumable.dart'; // Consumable 모델 임포트
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 임포트
import 'package:moring/widgets/car_viewer_section.dart';
import 'package:moring/widgets/consumables_section.dart'; // <-- 수정된 ConsumablesSection 임포트
import 'package:moring/widgets/driving_log_section.dart';
import 'package:moring/screens/information/more_information.dart';


class HomeContent extends ConsumerStatefulWidget {
  final Car? car;
  const HomeContent({Key? key, this.car}) : super(key: key);

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  int _selectedIndex = 0;
  late List<Consumable> consumables; // ConsumablesSection에 전달할 리스트
  List<String> _currentCarImagePaths = [];
  String _selectedCar = 'xm3';
  final List<String> _availableCars = ['xm3', '그렌저', '재규어'];

  final List<Map<String, String>> todayLogs = [
    {'distance': '15.2 mi', 'time': '12:30 PM - 1:00 PM'},
  ];
  final List<Map<String, String>> yesterdayLogs = [
    {'distance': '22.5 mi', 'time': '9:00 AM - 9:45 AM'},
    {'distance': '5.0 mi', 'time': '5:30 PM - 5:45 PM'},
  ];

  @override
  void initState() {
    super.initState();
    // ConsumablePartsScreen의 _initializeConsumables와 동일한 방식으로 초기화합니다.
    // 이렇게 해야 두 화면에서 동일한 데이터를 공유하는 효과를 낼 수 있습니다.
    final DateTime now = DateTime.now();
    consumables = [
      Consumable(
        icon: AppIcons.engineOil,
        title: 'Engine Oil',
        lastReplacedDate: DateTime(now.year, now.month - 1, now.day), // 1개월 전
        replacementCycleMonths: 6, // DB 기준: 6개월
      ),
      Consumable(
        icon: AppIcons.engineOil, // Oil Filter 아이콘은 Engine Oil과 유사
        title: 'Oil Filter',
        lastReplacedDate: DateTime(now.year, now.month - 2, now.day), // 2개월 전
        replacementCycleMonths: 6, // DB에 없으므로 Engine Oil과 유사하게 6개월 가정
      ),
      Consumable(
        icon: AppIcons.airFilter,
        title: 'Air Filter',
        lastReplacedDate: DateTime(now.year, now.month - 5, now.day), // 5개월 전
        replacementCycleMonths: 12, // DB 기준: 12개월
      ),
      Consumable(
        icon: AppIcons.airFilter, // Cabin Filter 아이콘은 Air Filter와 유사
        title: 'Cabin Filter',
        lastReplacedDate: DateTime(now.year, now.month - 7, now.day), // 7개월 전
        replacementCycleMonths: 12, // DB에 없으므로 유사하게 12개월 가정
      ),
      Consumable(
        icon: AppIcons.sparkPlugs,
        title: 'Spark Plugs',
        lastReplacedDate: DateTime(now.year, now.month - 1, now.day - 10), // 1개월 10일 전
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.breakFluid,
        title: 'Brake Fluid',
        lastReplacedDate: DateTime(now.year - 1, now.month - 10, now.day), // 1년 10개월 전 (낮은 진행률)
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.coolant,
        title: 'Coolant',
        lastReplacedDate: DateTime(now.year - 1, now.month - 11, now.day), // 1년 11개월 전 (매우 낮은 진행률)
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.transmissionFluid, // Transmission Fluid 아이콘 (AppIcons에 없음, 임시로 설정)
        title: 'Transmission Fluid',
        lastReplacedDate: DateTime(now.year, now.month, now.day - 5), // 5일 전 (매우 높은 진행률)
        replacementCycleMonths: 36, // DB에 없으므로 긴 주기 가정
      ),
      Consumable(
        icon: AppIcons.loccation, // 임시 타이어 아이콘 (AppIcons에 없음)
        title: 'Tire',
        lastReplacedDate: DateTime(now.year - 2, now.month, now.day), // 2년 전
        replacementCycleMonths: 36, // DB 기준: 36개월
      ),
      Consumable(
        icon: AppIcons.breakFluid, // 임시 브레이크 패드 아이콘 (AppIcons에 없음)
        title: 'Brake Pad',
        lastReplacedDate: DateTime(now.year - 1, now.month - 5, now.day), // 1년 5개월 전
        replacementCycleMonths: 24, // DB 기준: 24개월
      ),
      Consumable(
        icon: AppIcons.engineOil, // 임시 와이퍼 블레이드 아이콘 (AppIcons에 없음)
        title: 'Wiper Blade',
        lastReplacedDate: DateTime(now.year, now.month - 6, now.day), // 6개월 전
        replacementCycleMonths: 12, // DB 기준: 12개월
      ),
    ];

    if (widget.car != null) {
      _setCarImages(widget.car!.modelName);
    } else {
      _setCarImages(_selectedCar);
    }
  }

  void _setCarImages(String carName) {
    setState(() {
      _selectedCar = carName;
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
      }
      _currentCarImagePaths =
          List.generate(numImages, (i) => '$basePath${i + 1}.png');
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 하단바 탭 시 페이지 전환 로직
    if (index == 0) { // Home 탭 (인덱스 0)
      // 현재 HomeContent 화면이므로 특별한 Navigator 동작 없이 상태만 업데이트.
    } else if (index == 3) { // More 탭 (인덱스 3)
      // _selectedIndex가 3일 때 bodyContent가 MorePage로 변경되므로 Navigator.push 불필요.
    }
    // 다른 탭 (Navigation, Driving Log 등)에 대한 이동 로직은 필요에 따라 여기에 추가.
    // 예: else if (index == 1) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NavigationScreen())); }
  }

  Future<void> _logout() async {
    final repo = ref.read(tokenRepositoryProvider);
    final refreshToken = await repo.getRefreshToken();
    final dio = ref.read(noAuthDioProvider);
    final resp = await dio.post(
      '/api/v1/auth/logout/rToken',
      options: Options(
        headers: {'Cookie': 'refreshToken=$refreshToken'},
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    if (resp.statusCode == 200 || resp.statusCode == 302) {
      await repo.deleteAllTokens();
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_selectedIndex == 3) {
      // More 탭이 선택되면 MorePage를 body로 설정
      bodyContent = const MorePage();
    } else {
      // Home 탭 또는 다른 탭이 선택되면 기본 홈 화면 내용을 보여줍니다.
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CarViewerSection(imagePaths: _currentCarImagePaths),
            const SizedBox(height: 20),
            // === 이 부분이 ConsumablesSection 위젯을 사용하는 부분입니다. ===
            ConsumablesSection(consumables: consumables), // consumables 리스트를 전달
            const SizedBox(height: 20),
            DrivingLogSection(title: 'Today', logs: todayLogs),
            const SizedBox(height: 20),
            DrivingLogSection(title: 'Yesterday', logs: yesterdayLogs),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.car?.nickname ?? 'Moring',
        onBackButtonPressed: () => Navigator.pop(context),
        showCarDropdown: true,
        availableCars: _availableCars,
        selectedCar: _selectedCar,
        onCarChanged: (v) {
          if (v != null) _setCarImages(v);
        },
        onNotificationPressed: _logout,
      ),
      body: bodyContent,
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}