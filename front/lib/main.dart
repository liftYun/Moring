import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/root.dart';
import 'package:moring/screens/splash_screen.dart';
import 'package:moring/screens/member/login.dart';
import 'package:moring/screens/car/car_selection_page.dart';
import 'package:moring/screens/car/no_car.dart';
import 'package:moring/screens/car/car_registration.dart';
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
        data: (loggedIn) => loggedIn ? CarSelectionContainer() : const LoginPage(),
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home':  (context) => const HomePage(),
        '/carselection': (context) => CarSelectionContainer(),
        '/nocar': (context) => const CarNotRegisteredPage(),
      },
    );
  }
}