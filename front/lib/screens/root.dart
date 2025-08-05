
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/utils/bottom_nav_bar.dart';

import '../providers/api_client.dart';
import '../providers/token_repository.dart';
import '../utils/custom_app_bar.dart';

/// 로그인 후 진입하는 메인 탭 컨테이너
class RootPage extends ConsumerStatefulWidget {
  // final Car?car;
  const RootPage({super.key});
  // const RootPage({Key? key, this.car}) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _currentIndex = 0;
  // 탭별 화면 리스트
  static const List<Widget> _pages = <Widget>[
    HomePage(),           // HomeContent 만 보여주도록 HomePage 수정 필요
    HomePage(),          // MapScreen: 네비게이션 탭
    HomePage(),     // DrivingLogPage: 주행 기록 탭
    MorePage(),           // MorePage: 마이페이지 탭

  ];

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

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Moring',
        onBackButtonPressed: () {
          Navigator.pop(context); // 이전 화면(HomePage)으로 돌아가기
        },
        // showCarDropdown: true,
        // availableCars: _availableCars,
        // selectedCar: _selectedCar,
        // onCarChanged: (v) {
        //   if (v != null) _setCarImages(v);
        // },
        onNotificationPressed: _logout,
      ),
      // AppBar(title: const Text('Navigation')),
      // AppBar(title: const Text('Driving Log')),
      // AppBar(title: const Text('My Page')),

      // 탭 스위칭
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // 한 번만 배치하는 BottomNavBar
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _currentIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}