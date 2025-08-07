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
import '../providers/car_provider.dart';
import '../providers/notification_api_provider.dart';
import 'information/notification_panel.dart';

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

    // 화면 렌더링 후에 한 번만 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCount();
    });

    // 1분마다 폴링
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadCount();
    });

    // FCM 푸시 수신 시 갱신
    FirebaseMessaging.onMessage.listen((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final vin = ref.read(currentVinProvider);
    // final vin = widget.initialCar?.vin ?? ref.read(currentVinProvider);
    debugPrint('🏠[RootPage] _loadCount 호출 – 현재 VIN: $vin');
    if (vin == null) return;

    final api = ref.read(notificationApiProvider);
    try {
      final count = await api.fetchUnreadCount(vin);
      debugPrint('🏠[RootPage] fetchUnreadCount 응답: $count');
      if (count != _unreadCount) {
        setState(() => _unreadCount = count);
        debugPrint('🏠[RootPage] _unreadCount 업데이트: $_unreadCount');
      }
    } catch (e, st) {
      debugPrint('🏠[RootPage] 뱃지 카운트 에러: $e\n$st');
    }
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
    // HomePage(car: widget.initialCar),    // ← 여기서 전달된 car 사용
    const HomePage(),
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
      onBackButtonPressed: _handleBack,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      withBottomNav: true,                 // 바텀바를 쓰겠다
      selectedIndex: _currentIndex,        // 현재 탭
      onItemTapped: _onItemTapped,         // 탭 누르면 이 콜백이 불린다
      showNotificationButton: true,
      onNotificationButtonPressed: _openNotificationPanel,
      notificationCount: _unreadCount,
    );
  }
  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    else nav.pushNamedAndRemoveUntil('/carselection', (_) => false);
  }

  void _openNotificationPanel() {
    final vin = ref.read(currentVinProvider);
    if (vin == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return NotificationPanel();
      },
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }
}
