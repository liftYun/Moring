import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스가 필요합니다.

// AppBar를 재사용 가능한 위젯으로 분리 (차량 선택 기능 제거)

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackButtonPressed; // 뒤로가기 버튼 콜백
  final VoidCallback? onNotificationPressed; // 알림 버튼 콜백


  const CustomAppBar({
    Key? key,
    required this.title,
    this.onBackButtonPressed,
    this.onNotificationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        // 알림 버튼
        IconButton(
          icon: AppIcons.notifications,
          onPressed: onNotificationPressed, // 외부에서 전달받은 콜백 사용
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // 기본 AppBar 높이
}