import 'package:flutter/material.dart';
import 'package:moring/screens/member/user_info_edit.dart';
import 'package:moring/utils/app_icon.dart';

import '../screens/member/mypage.dart'; // AppIcons를 사용하기 위해 임포트

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: AppIcons.home,       label: 'Home'),
        BottomNavigationBarItem(icon: AppIcons.navigation, label: 'Navigation'),
        BottomNavigationBarItem(icon: AppIcons.drivingLog, label: 'Driving Log'),
        BottomNavigationBarItem(icon: AppIcons.more,       label: 'More'),
      ],
      currentIndex: selectedIndex,
      onTap: (index) {
        if (index == 3) {
          // “More” 아이템 전체영역 터치 시 팝업 띄우기
          _showMoreMenu(context);
        } else {
          // 나머지 탭은 원래대로 스위칭
          onItemTapped(index);
        }
      },
      type: BottomNavigationBarType.fixed,
    );
  }

  void _showMoreMenu(BuildContext context) async {
    // 화면 아래쪽 중앙에 메뉴 띄우기 (원하는 위치로 조정 가능)
    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,                       // 왼쪽 여백
        MediaQuery.of(context).size.height - 200, // 위쪽 위치
        0,   // 오른쪽 여백
        0,
      ),
      items: const [
        PopupMenuItem(value: 3, child: Text('Profile')),
        PopupMenuItem(value: 4, child: Text('App Settings')),
        PopupMenuItem(value: 5, child: Text('Support')),
        PopupMenuItem(value: 6, child: Text('More')), // 다시 “More” 탭으로
      ],
    );

    // 사용자가 선택한 값 처리
    switch (result) {
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileEditPage()),
        );
        break;
      case 4:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileEditPage()),
        );
        break;
      case 5:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileEditPage()),
        );
        break;
      case 6:
        onItemTapped(3); // “More” 탭 자체로 돌아가기
        break;
      default:
        break;
    }
  }
}
