import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/screens/navigation/navigation_page.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';

import '../models/car.dart';

class RootPage extends ConsumerStatefulWidget {
  final Car? initialCar;
  const RootPage({Key? key, this.initialCar}) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _currentIndex = 0;
  static const _titles = ['Moring', 'Navigation', 'Driving Log', 'More'];

  List<Widget> get _pages => <Widget>[
    HomePage(car: widget.initialCar),    // Home 탭
    const NavigationPage(),              // Navigation 탭 - 우리 네비게이션 기능
    const HomePage(),                    // Driving Log 탭
    const MorePage(),                    // More 탭
  ];

  void _onItemTapped(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: _titles[_currentIndex],
      showBack: true,
      onBackButtonPressed: () {
        final nav = Navigator.of(context);
        if (Navigator.of(context).canPop()) {
          nav.pop();
        } else {
          nav.pushNamedAndRemoveUntil('/carselection',(route) => false,);
        }
      },
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      withBottomNav: true,                 // 바텀바를 쓰겠다
      selectedIndex: _currentIndex,        // 현재 탭
      onItemTapped: _onItemTapped,         // 탭 누르면 이 콜백이 불린다
      onNotificationPressed: null,      // 오른쪽 아이콘 콜백
    );
  }
}
