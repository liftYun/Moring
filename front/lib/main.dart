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
import 'package:moring/screens/car/registration_complete.dart';
import 'package:moring/screens/car_regist_ocr.dart';
import 'package:moring/utils/app_theme.dart';
import 'package:moring/models/car.dart';
import 'providers/auth_provider.dart';
// firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/fcm_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/local_notification_service.dart';
// 주행 로그 백그라운드 서비스 추가
import 'package:moring/screens/navigation/services/daily_log_backup_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🆕 RouteObserver 추가 - 네비게이션 화면 생명주기 추적용
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.showNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(
    nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',
    javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',
  );

  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await LocalNotificationService.init();

  } catch (e) {
    debugPrint('Firebase/FCM 초기화 실패: $e');
  }

  // 🆕 주행 로그 백그라운드 서비스 초기화
  try {
    debugPrint('🔄 주행 로그 백그라운드 서비스 초기화 중...');
    await DailyLogBackupService.initialize();
    debugPrint('✅ 주행 로그 백그라운드 서비스 초기화 완료');
  } catch (e) {
    debugPrint('❌ 주행 로그 백그라운드 서비스 초기화 실패: $e');
  }

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

    ref.listen<String?>(fCMNotifierProvider, (previous, next) {
      if (next != null) {
        debugPrint('FCM 토큰 상태 변경(전체 토큰): ${next}...');
      }
    });

    return OverlaySupport.global( // 👈 추가: Overlay 지원
      child: MaterialApp(
	      navigatorKey: navigatorKey,   // ← 여기에 추가
        title: 'Moring App',
        theme: AppTheme, // utils/app_theme.dart 에 정의
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        home: authAsync.when(
          loading: () => const SplashScreen(),
          error: (_, __) => const LoginPage(),
          data: (loggedIn) => loggedIn ? CarSelectionContainer() : const LoginPage(),
        ),
        routes: {
          '/login': (context) => const LoginPage(),
          '/carselection': (context) => CarSelectionContainer(),
          '/nocar': (context) => const CarNotRegisteredPage(),
	        '/root': (context) => const RootPage(),
          '/registration': (context) => const CarRegistrationPage(),
          '/car_ocr': (context) => const CarOcrRegistrationPage(),
          '/registration_complete': (context) => const RegistrationCompletePage(),
        },
      ),
    );  // OverlaySupport.global 닫는 괄호
  }
}