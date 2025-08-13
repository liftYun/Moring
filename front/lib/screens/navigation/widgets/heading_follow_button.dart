import 'package:flutter/material.dart';

class HeadingFollowButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const HeadingFollowButton({super.key, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 🆕 검색바와 겹치지 않도록 위치 조정
    final searchBarHeight = screenHeight * 0.055;
    final searchBarMargin = screenHeight * 0.02;
    final buttonTopMargin = searchBarMargin + searchBarHeight + 16; // 검색바 아래 16px 여백
    
    // 🆕 내 위치 버튼과 같은 크기로 설정
    final buttonSize = screenHeight * 0.055; // MyLocationButton과 동일한 크기
    
    return Positioned(
      top: buttonTopMargin,
      right: 16,
      child: Container(
        width: buttonSize,  // 🆕 동일한 크기
        height: buttonSize, // 🆕 동일한 크기
        decoration: BoxDecoration(
          color: enabled ? Colors.indigo : Colors.white,
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
                Icons.explore, // 나침반 아이콘
                color: enabled ? Colors.white : Colors.black87,
                size: buttonSize * 0.45, // 🆕 MyLocationButton과 동일한 아이콘 비율
              ),
            ),
          ),
        ),
      ),
    );
  }
}