import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';

import '../models/car.dart';
import '../providers/notification_api_provider.dart';

class RootPage extends ConsumerStatefulWidget {
  final Car? initialCar;
  const RootPage({Key? key, this.initialCar}) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage>
    with WidgetsBindingObserver {
  int _unreadCount = 0;
  int _currentIndex = 0;
  Timer? _timer;
  static const _titles = ['Moring', 'Navigation', 'Driving Log', 'More'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 즉시 로드
    _loadCount();

    // 30초마다 폴링
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadCount();
    });

    // FCM 푸시 수신 시 갱신
    FirebaseMessaging.onMessage.listen((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final api = ref.read(notificationApiProvider);
    try {
      // final cnt = await api.fetchUnreadCount(ref.read());
      final count = await ref.read(notificationApiProvider).fetchUnreadCount(vin);
      if (cnt != _unreadCount) {
        setState(() => _unreadCount = cnt);
      }
    } catch (_) { /* 에러 무시 혹은 로깅 */ }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  List<Widget> get _pages => <Widget>[
    HomePage(car: widget.initialCar),    // ← 여기서 전달된 car 사용
    const HomePage(),
    const HomePage(),
    const MorePage(),
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
      showNotificationButton: true,
      notificationCount: _unreadCount,
    );
  }
}
