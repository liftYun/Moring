// lib/utils/base_scaffold.dart
import 'package:flutter/material.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/bottom_nav_bar.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  /// 탭이 필요한 페이지라면 true
  final bool withBottomNav;
  final int selectedIndex;
  final ValueChanged<int>? onItemTapped;
  final bool showBack;
  final VoidCallback? onBackButtonPressed;

  /// 알림 버튼 보일지 여부
  final bool showNotificationButton;
  /// 알림 개수
  final int notificationCount;

  const BaseScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.withBottomNav = false,
    this.selectedIndex = 0,
    this.onItemTapped,
    this.showBack = false,
    this.onBackButtonPressed,
    this.showNotificationButton = true,
    this.notificationCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: title,
        onBackButtonPressed: showBack ? onBackButtonPressed : null,
        showNotificationButton: showNotificationButton,
        notificationCount: notificationCount,
      ),
      body: body,
      bottomNavigationBar: withBottomNav && onItemTapped != null
          ? CustomBottomNavBar(
        selectedIndex: selectedIndex,
        onItemTapped: onItemTapped!,
      )
          : null,
    );
  }
}
