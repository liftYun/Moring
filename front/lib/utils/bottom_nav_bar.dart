import 'package:flutter/material.dart';
import 'package:moring/screens/member/user_info_edit.dart';
import 'package:moring/screens/car/car_registration.dart';
import 'package:moring/utils/app_icon.dart';
import 'package:moring/screens/information/notification_log.dart';
import 'package:moring/screens/information/inspection_detail_container.dart';

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
        BottomNavigationBarItem(icon: AppIcons.home,       label: '홈'),
        BottomNavigationBarItem(icon: AppIcons.navigation, label: '내비게이션'),
        BottomNavigationBarItem(icon: AppIcons.drivingLog, label: '주행 로그'),
        BottomNavigationBarItem(icon: AppIcons.more,       label: '더보기'),
      ],
      currentIndex: selectedIndex,
      onTap: (index) {
        // if (index == 3) {
        //   // “More” 아이템 전체영역 터치 시 팝업 띄우기
        //   _showMoreMenu(context);
        // } else {
        //   // 나머지 탭은 원래대로 스위칭
          onItemTapped(index);
        // }
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
        PopupMenuItem(value: 3, child: Text('프로필')),
        PopupMenuItem(value: 4, child: Text('점검 로그')),
        PopupMenuItem(value: 5, child: Text('알림')),
        PopupMenuItem(value: 6, child: Text('더보기')), // 다시 “More” 탭으로
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
          MaterialPageRoute(builder: (_) => const InspectionDetailContainerPage()),
        );
        break;
      case 5:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationLogPage()),
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
