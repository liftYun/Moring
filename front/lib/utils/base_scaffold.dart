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
  final bool showCarDropdown;
  final List<String>? availableCars; // 차량 목록 (옵션)
  final String? selectedCar; // 현재 선택된 차량 (옵션)
  final ValueChanged<String?>? onCarChanged; // 차량 변경 콜백 (옵션)
  final VoidCallback? onNotificationPressed;
  final bool showBack;
  final VoidCallback? onBackButtonPressed;

  const BaseScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.withBottomNav = false,
    this.selectedIndex = 0,
    this.onItemTapped,
    this.showCarDropdown = false, // 기본값은 false로 설정하여 숨김
    this.availableCars,
    this.selectedCar,
    this.onCarChanged,
    this.onNotificationPressed,
    this.showBack = false,
    this.onBackButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: title,
        onBackButtonPressed: showBack ? onBackButtonPressed : null,
        onNotificationPressed: onNotificationPressed,
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
