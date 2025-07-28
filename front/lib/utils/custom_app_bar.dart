import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스가 필요합니다.

// AppBar를 재사용 가능한 위젯으로 분리 (차량 선택 기능 제거)

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackButtonPressed; // 뒤로가기 버튼 콜백
  final VoidCallback? onNotificationPressed; // 알림 버튼 콜백
  final bool showCarDropdown; // 차량 드롭다운 표시 여부 (옵션)
  final List<String>? availableCars; // 차량 목록 (옵션)
  final String? selectedCar; // 현재 선택된 차량 (옵션)
  final ValueChanged<String?>? onCarChanged; // 차량 변경 콜백 (옵션)


  const CustomAppBar({
    Key? key,
    required this.title,
    this.onBackButtonPressed,
    this.onNotificationPressed,
    this.showCarDropdown = false, // 기본값은 false로 설정하여 숨김
    this.availableCars,
    this.selectedCar,
    this.onCarChanged,
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
        // 차량 선택 드롭다운 메뉴 (showCarDropdown이 true일 때만 표시)
        if (showCarDropdown && availableCars != null && selectedCar != null && onCarChanged != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCar,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                dropdownColor: Colors.grey[850], // 드롭다운 배경색
                onChanged: onCarChanged, // 외부에서 전달받은 콜백 사용
                items: availableCars!.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()), // 차량 이름을 대문자로 표시
                  );
                }).toList(),
              ),
            ),
          ),
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