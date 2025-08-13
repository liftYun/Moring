// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:moring/screens/home_page.dart';
import 'package:moring/screens/navigation/services/daily_log_backup_service.dart';
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

// ✅ dotenv 추가
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.showNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ .env를 가장 먼저 로드 (assets에 .env 등록 필요)
  await dotenv.load(fileName: ".env");

  KakaoSdk.init(
    nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',       // ← 그대로 두면 됨
    javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',    // ← 그대로 두면 됨
  );

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await LocalNotificationService.init();
  } catch (e) {
    debugPrint('Firebase/FCM 초기화 실패: $e');
  }

  // 🆕 주행 로그 백그라운드 서비스 초기화 (기존 - 일일 백업)
  try {
    // debugPrint('🔄 4시간 백업 서비스 초기화 중...');
    await DailyLogBackupService.initialize();
    debugPrint('✅ 4시간 백업 서비스 초기화 완료');
  } catch (e) {
    debugPrint('❌ 4시간 백업 서비스 초기화 실패: $e');
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

    return OverlaySupport.global(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Moring App',
        theme: AppTheme,
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
    );
  }
}
