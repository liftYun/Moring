import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/app_icon.dart';
import 'package:moring/widgets/car_viewer_section.dart';
import 'package:moring/widgets/consumables_section.dart';
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
  late List<Consumable> consumables;
  List<String> _currentCarImagePaths = [];
  String _selectedCar = 'xm3';
  final List<String> _availableCars = ['xm3', '그렌저', '재규어'];

  // 예시용 하드코딩 로그 (나중에 API 연동)
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

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

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
      // More 탭
      bodyContent = const MorePage();
    } else {
      // Home 탭
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CarViewerSection(imagePaths: _currentCarImagePaths),
            const SizedBox(height: 20),
            ConsumablesSection(consumables: consumables),
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
