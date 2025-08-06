import 'package:flutter/material.dart';
import 'package:moring/screens/root.dart';
import 'package:moring/utils/app_icon.dart';

import '../screens/information/notification_page.dart'; // AppIcons 클래스가 필요합니다.

// AppBar를 재사용 가능한 위젯으로 분리 (차량 선택 기능 제거)

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int notificationCount;
  final VoidCallback? onBackButtonPressed; // 뒤로가기 버튼 콜백
  final bool showNotificationButton;


  const CustomAppBar({
    Key? key,
    required this.title,
    this.onBackButtonPressed,
    this.showNotificationButton = true,
    this.notificationCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int cnt = notificationCount;
    return AppBar(
      leading: onBackButtonPressed != null
          ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackButtonPressed,
      )
          : null, // 콜백이 없으면 버튼 표시 안 함
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      centerTitle: true,
      actions: [
        if (showNotificationButton)
          // 알림 버튼
          IconButton(
            // icon: AppIcons.notifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcons.notifications,
                if(cnt > 0) Positioned(
                  right: -2,
                  top: -2,
                  child: _buildBadge(cnt),
                )
              ],
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationPage(),
                ),
              );
            },
          ),
      ],
    );
  }

  /// 뱃지 위젯 (1~9: 숫자, >=10: 점)
  Widget _buildBadge(int cnt) {
    if (cnt < 10) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Center(
          child: Text(
            '$cnt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      return const SizedBox(
        width: 12,
        height: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // 기본 AppBar 높이
}