// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:moring/utils/app_icon.dart'; // AppIcons 클래스 임포트
// import 'package:moring/utils/bottom_nav_bar.dart'; // CustomBottomNavBar 위젯 임포트
// import 'package:moring/utils/app_theme.dart'; // CustomBottomNavBar 위젯 임포트
// import 'package:moring/utils/custom_app_bar.dart'; // CustomBottomNavBar 위젯 임포트
// import 'package:moring/models/consumable.dart'; // Consumable 모델 임포트 (수정: utils/ -> models/ 로 경로 변경)
// import 'package:moring/widgets/car_360_viewer.dart'; // Car360Viewer 위젯 임포트
// import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
// import 'screens/home_page.dart';
// import 'screens/member/login.dart';
// import 'screens/map/map.dart';
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // 🔑 카카오 SDK 초기화 (반드시 runApp 이전에)
//   KakaoSdk.init(
//     nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',
//     javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',
//   );
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Moring App',
//       // 다크 모드 테마 설정
//       theme: AppTheme,
//       home: const HomePage(),
//
//       // ↓ 로그인 화면을 첫 화면으로 지정
//       initialRoute: '/login',
//       routes: {
//         '/login': (c) => const LoginPage(),
//         '/home':  (c) => const HomePage(), // 또는 MapScreen()
//       },
//     );
//   }
// }
//
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:moring/screens/splash_screen.dart';
import 'package:moring/screens/member/login.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/car/car_selection_page.dart';
import 'package:moring/screens/car/no_car.dart';
import 'package:moring/utils/app_theme.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(
    nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',
    javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',
  );
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(isLoggedInProvider);
    return MaterialApp(
      title: 'Moring App',
      theme: AppTheme, // utils/app_theme.dart 에 정의
      debugShowCheckedModeBanner: false,
      home: authAsync.when(
        loading: () => const SplashScreen(),
        error: (_, __) => const LoginPage(),
        data: (loggedIn) => loggedIn ? const HomePage() : const LoginPage(),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home':  (context) => const HomePage(),
        '/carSelection': (context) => const CarSelectionPage(),
        '/noCar': (context) => const CarNotRegisteredPage(),
      },
    );
  }
}
