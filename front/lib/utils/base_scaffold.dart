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
