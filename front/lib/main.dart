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
import 'package:moring/screens/ocr.dart';
import 'package:moring/utils/app_theme.dart';
import 'providers/auth_provider.dart';
// firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/fcm_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/local_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // print('message :  ${message.toMap()}');
  // print('백그라운드에서 알림 수신: ${message.notification?.title}');

  await LocalNotificationService.showNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(
    nativeAppKey: 'b0c6ed29bed9644abb543aac61d3e0d6',
    javaScriptAppKey: 'e9de537a4f886944859b124acbc8f5e4',
  );

  try {
    //Firebase 초기화
    await Firebase.initializeApp();

    // FCM 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await LocalNotificationService.init();

  } catch (e) {
    print('Firebase/FCM 초기화 실패: $e');
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

    // FCM Provider 감시 및 초기화 트리거
    ref.listen<String?>(fCMNotifierProvider, (previous, next) {
      if (next != null) {
        // print('FCM 토큰 상태 변경: ${next.substring(0, 20)}...');
        print('FCM 토큰 상태 변경(전체 토큰): ${next}...');
        // FCM 토큰이 생성되거나 갱신될 때마다 호출됨
      }
    });

    // 로그인 상태 변화 감시하여 FCM 자동 처리
    ref.listen<AsyncValue<bool>>(isLoggedInProvider, (previous, next) {
      next.whenData((isLoggedIn) async {
        final fcmNotifier = ref.read(fCMNotifierProvider.notifier);

        if (isLoggedIn) {
          // print('로그인 감지 - FCM 토큰 서버 전송');
          await fcmNotifier.sendTokenAfterLogin();
        } else {
          // print('로그아웃 감지 - FCM 알림 차단');
          await fcmNotifier.handleLogout();
        }
      });
    });

    return OverlaySupport.global( // 👈 추가: Overlay 지원
      child: MaterialApp(
	navigatorKey: navigatorKey,   // ← 여기에 추가
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
          '/carselection': (context) => CarSelectionContainer(),
          '/nocar': (context) => const CarNotRegisteredPage(),
	        '/root': (context) => const RootPage(),
          '/registration': (context) => const CarRegistrationPage(),
          '/ocr': (context) => const OcrRegistrationPage(),
          '/registration_complete': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            final modelName = args?['modelName'] as String;
            return RegistrationCompletePage(modelName: modelName);
          }
        },
      ),
    );
  }
}