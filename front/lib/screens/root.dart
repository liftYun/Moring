import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/screens/member/mypage.dart';
import 'package:moring/screens/information/more_information.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';

import '../models/car.dart';
import '../providers/car_provider.dart';
import '../providers/notification_api_provider.dart';
import 'information/notification_panel.dart';
import 'package:moring/screens/information/driving_record_container.dart'; // ✅ 추가
import 'navigation/navigation_page.dart';

class RootPage extends ConsumerStatefulWidget {
  final Car? initialCar;
  const RootPage({Key? key, this.initialCar}) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage>
    with WidgetsBindingObserver {
  // int _unreadCount = 0;
  int _currentIndex = 0;
  Timer? _timer;
  static const _titles = ['Moring', '내비게이션', '주행 로그', '더보기'];

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
      ref.read(unreadCountProvider.notifier).state = count;
      // if (count != _unreadCount) {
      //   // setState(() => _unreadCount = count);
      //   ref.read(unreadCountProvider.notifier).state = count;
      //   debugPrint('🏠[RootPage] _unreadCount 업데이트: $_unreadCount');
      // }
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

  // List<Widget> get _pages => <Widget>[
  //   // HomePage(car: widget.initialCar),    // ← 여기서 전달된 car 사용
  //   const HomePage(),
  //   const NavigationPage(),
  //   const HomePage(),
  //   const MorePage(),
  // ];

  // 🎯 하이브리드 방식: 네비게이션(1번)만 Container로 대체, 주행로그(2번)는 이미 Lazy Loading
  List<Widget> get _pages => <Widget>[
    const HomePage(),           // 0번 탭 (홈) - IndexedStack
    Container(),                // 1번 탭 (네비게이션) - 빈 컨테이너 (Lazy Loading으로 변경)
    Container(),                // 2번 탭 (주행로그) - 빈 컨테이너 (이미 Lazy Loading 사용중)
    const MorePage(),           // 3번 탭 (더보기) - IndexedStack
  ];

  void _onItemTapped(int index) {
    // 1 = 네비게이션 탭: 별도 화면으로 push
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NavigationPage(),
        ),
      );
      return; // 현재 탭 인덱스는 변경하지 않음
    }

    // 2 = Driving Log 탭
    if (index == 2) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => const DrivingRecordContainerPage(), // ✅ 컨테이너가 조회 후 기존 페이지로 넘김
        ),
      );
      return; // 현재 탭(IndexedStack 인덱스)은 유지
    }

    setState(() => _currentIndex = index);
  }
  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider);
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
      notificationCount: count,
    );
  }
  void _handleBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      // 홈 화면이 아닌 경우 홈 화면으로 이동
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      } else {
        // 홈 화면에서 뒤로가기를 누르면 차량 선택 페이지로 이동
        Navigator.pushReplacementNamed(context, '/carselection');
      }
    }
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
