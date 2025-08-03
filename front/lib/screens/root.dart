
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/utils/bottom_nav_bar.dart';

/// 로그인 후 진입하는 메인 탭 컨테이너
class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});

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

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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