import 'package:flutter/material.dart';
// AppIcons 클래스가 테마 내에서 사용될 경우 (현재 테마에는 직접 사용되지 않지만, 다른 곳에서 테마와 함께 사용될 수 있으므로 참고)

// 앱의 공통 테마 데이터를 정의하는 파일

final ThemeData AppTheme = ThemeData(
  brightness: Brightness.dark, // 전체적으로 다크 모드
  primarySwatch: Colors.teal, // 주요 색상
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black, // 앱바 배경색
    foregroundColor: Colors.white, // 앱바 아이콘 및 텍스트 색상
  ),
  scaffoldBackgroundColor: Colors.black, // Scaffold 전체 배경색
  cardColor: Colors.grey[900], // 카드 배경색 (이미지에서 보이는 진한 회색)
  // 텍스트 테마 설정 (Flutter의 dp 단위 사용, rem 개념은 Flutter에 직접 적용되지 않음)
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: Colors.white, fontSize: 57),
    displayMedium: TextStyle(color: Colors.white, fontSize: 45),
    displaySmall: TextStyle(color: Colors.white, fontSize: 36),
    headlineLarge: TextStyle(color: Colors.white, fontSize: 32),
    headlineMedium: TextStyle(color: Colors.white, fontSize: 28),
    headlineSmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), // '소모품 현황'
    titleLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), // 'Today', 'Yesterday' 타이틀
    titleMedium: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), // 소모품 제목, 주행 거리
    titleSmall: TextStyle(color: Colors.white, fontSize: 16),
    bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
    bodySmall: TextStyle(color: Colors.grey, fontSize: 12), // 날짜, 시간 정보
    labelLarge: TextStyle(color: Colors.white, fontSize: 14),
    labelMedium: TextStyle(color: Colors.white, fontSize: 12),
    labelSmall: TextStyle(color: Colors.white, fontSize: 11),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.grey[900], // 하단 바 배경색
    selectedItemColor: Colors.tealAccent, // 선택된 아이템 색상
    unselectedItemColor: Colors.grey, // 선택되지 않은 아이템 색상
    showUnselectedLabels: true, // 선택되지 않은 라벨도 항상 표시
    type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 때도 고정
  ),
);