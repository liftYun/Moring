import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons를 사용하기 위해 임포트

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    // BottomNavigationBarThemeData는 MyApp에서 설정했으므로 여기서 다시 설정할 필요는 없습니다.
    // 하지만 필요하다면 여기서 오버라이드할 수 있습니다.
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: AppIcons.home,
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: AppIcons.navigation,
          label: 'Navigation',
        ),
        BottomNavigationBarItem(
          icon: AppIcons.drivingLog,
          label: 'Driving Log',
        ),
        BottomNavigationBarItem(
          icon: AppIcons.more,
          label: 'More',
        ),
      ],
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 때도 고정
    );
  }
}