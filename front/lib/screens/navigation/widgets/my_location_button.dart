import 'package:flutter/material.dart';

class MyLocationButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isDriving; // 운전 상태 받아오기
  final Color? backgroundColor;
  final Color? iconColor;

  const MyLocationButton({
    super.key,
    this.onPressed,
    required this.isDriving, // 필수 파라미터
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // 🎯 동적 크기 및 위치 계산 (위젯 내부에서)
    final dynamicMargin = screenHeight * 0.02;        // 화면 높이의 2%
    final infoBarHeight = screenHeight * 0.07;        // 주행 정보바 높이
    final buttonHeight = screenHeight * 0.06;         // 운전 버튼 높이
    final buttonSize = screenHeight * 0.055;          // 내 위치 버튼 크기

    // 운전 중일 때와 아닐 때의 bottom 위치 계산
    double bottomPosition;

    if (isDriving) {
      // 운전 중: 주행 정보바 + 운전 버튼 + 여백들을 고려
      bottomPosition = dynamicMargin +           // 하단 여백
          buttonHeight +             // 운전 버튼 높이
          12 +                       // 주행 정보바와 운전 버튼 사이 간격
          infoBarHeight +            // 주행 정보바 높이
          (buttonSize * 0.3);        // 내 위치 버튼과 주행 정보바 사이 간격 (0.15 → 0.3)
    } else {
      // 정지 중: 운전 버튼만 고려
      bottomPosition = dynamicMargin +           // 하단 여백
          buttonHeight +             // 운전 버튼 높이
          (buttonSize * 0.4);        // 내 위치 버튼과 운전 버튼 사이 간격 (0.15 → 0.4)
    }

    return Positioned(
      bottom: bottomPosition,
      right: 16,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(buttonSize / 2),
            child: Center(
              child: Icon(
                Icons.my_location,
                color: iconColor ?? Colors.teal[600],
                size: buttonSize * 0.45, // 버튼 크기의 45%
              ),
            ),
          ),
        ),
      ),
    );
  }
}