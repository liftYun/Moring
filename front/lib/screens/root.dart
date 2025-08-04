import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';

class RootPage extends ConsumerStatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _currentIndex = 0;
  static const _titles = ['Moring', 'Navigation', 'Driving Log', 'More'];

  static const _pages = <Widget>[
    HomePage(),
    HomePage(),      // 네비게이션 화면,
    HomePage(),      // 주행 기록 화면
    MorePage(),      // 더보기 화면
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

  void _onItemTapped(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: _titles[_currentIndex],
      body: _pages[_currentIndex],
      withBottomNav: true,                 // 바텀바를 쓰겠다
      selectedIndex: _currentIndex,        // 현재 탭
      onItemTapped: _onItemTapped,         // 탭 누르면 이 콜백이 불린다
      onNotificationPressed: _logout,      // 오른쪽 아이콘 콜백
    );
  }
}
