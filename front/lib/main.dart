// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:moring/screens/navigation/services/daily_log_backup_service.dart';
import 'package:moring/screens/root.dart';
import 'package:moring/screens/splash_screen.dart';
import 'package:moring/screens/member/login.dart';
import 'package:moring/screens/car/car_selection_page.dart';
import 'package:moring/screens/car/no_car.dart';
import 'package:moring/screens/car/car_registration.dart';
import 'package:moring/screens/car/car_regist_ocr.dart';
import 'package:moring/screens/car/registration_complete.dart';
import 'package:moring/screens/navigation/navigation_page.dart';
import 'package:moring/screens/information/driving_record.dart';
import 'package:moring/screens/information/more_information.dart';


import 'package:moring/utils/app_theme.dart';
import 'providers/auth_provider.dart';

import 'package:moring/sse/sse_bootstrap.dart';
import 'package:moring/sse/sse_hub.dart';
// firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/fcm_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/local_notification_service.dart';

// ✅ dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ✅ 전역 SSE 오버레이 (미등록 사용자 감지 + 모달 + TTS + "아니요→SMS")
import 'package:moring/screens/navigation/sse_unknown_face.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.showNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ .env를 가장 먼저 로드
  await dotenv.load(fileName: ".env");

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

  // 🆕 일일 백업(4시간 주기)
  try {
    await DailyLogBackupService.initialize();
    debugPrint('✅ 4시간 백업 서비스 초기화 완료');
  } catch (e) {
    debugPrint('❌ 4시간 백업 서비스 초기화 실패: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

// lib/main.dart  (MyApp만 교체하면 됩니다)
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(isLoggedInProvider);

    // 이건 build 안에서 호출하므로 OK
    ref.listen<String?>(fCMNotifierProvider, (previous, next) {
      if (next != null) {
        debugPrint('FCM 토큰 상태 변경: $next');
      }
    });

    return OverlaySupport.global(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Moring App',
        theme: AppTheme,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],

        // ✅ 전역 오버레이는 여기서만 깔기
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            const SseBootstrap(),            // VIN 전환 전담
            const UnknownFaceSSEOverlay(),   // 전역 비인가 사용자 모달
          ],
        ),

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
          '/navigation': (context) => const NavigationPage(),
          '/driving_record': (context) => const DrivingRecordPage(),
          '/more': (context) => const MorePage(),
        },
      ),
    );
  }
}

