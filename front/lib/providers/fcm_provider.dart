// lib/providers/fcm_provider.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:moring/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:moring/widgets/custom_notification.dart';

part 'fcm_provider.g.dart';

@riverpod
class FCMNotifier extends _$FCMNotifier {
  late final TokenRepository _tokenRepository;
  late final FirebaseMessaging _firebaseMessaging;
  late final Dio _dio;
  late final FlutterSecureStorage _storage;

  String? _fcmToken;

  @override
  String? build() {
    // 의존성 주입
    _tokenRepository = ref.read(tokenRepositoryProvider);
    _firebaseMessaging = FirebaseMessaging.instance;
    _dio = ref.read(authDioProvider);
    _storage = const FlutterSecureStorage();

    // FCM 초기화를 자동으로 시작
    _initializeAsync();

    return null; // 초기 FCM 토큰 상태
  }

  /// 비동기 초기화 (build에서 Future를 반환할 수 없으므로 별도 메서드)
  void _initializeAsync() {
    Future.microtask(() => initialize());
  }

  /// Firebase 초기화 및 FCM 설정
  Future<void> initialize() async {
    try {
      // Firebase 초기화
      await Firebase.initializeApp();
      print('Firebase 초기화 완료');

      // FCM 권한 요청 (iOS는 필수, Android는 선택)
      await _requestPermission();

      // FCM 토큰 생성
      await _generateToken();

      // 메시지 리스너 설정
      _setupMessageHandlers();

      print('FCM 초기화 완료');
    } catch (e) {
      print('FCM 초기화 실패: $e');
    }
  }

  /// 알림 권한 요청
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,      // 알림 표시
      badge: true,      // 앱 아이콘 배지
      sound: true,      // 알림 소리
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('알림 권한 허용됨');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('임시 알림 권한 허용됨');
    } else {
      print('알림 권한 거부됨');
    }
  }

  /// FCM 토큰 생성 및 저장
  Future<void> _generateToken() async {
    try {
      // FCM 토큰 가져오기
      String? savedToken = await _storage.read(key: 'fcm_token');

      if (savedToken != null && savedToken.isNotEmpty) {

        // 기존 토큰이 있으면 사용
        _fcmToken = savedToken;
        state = savedToken;
        print('기존 FCM 토큰 로드: ${savedToken.substring(0, 20)}...');
        print('기존 FCM 토큰(전체): $savedToken');

      } else {

        // 기존 토큰이 없으면 새로 생성
        _fcmToken = await _firebaseMessaging.getToken();

        if (_fcmToken != null) {
          // SecureStorage에 저장
          await _storage.write(key: 'fcm_token', value: _fcmToken!);
          state = _fcmToken;
          print('새 FCM 토큰 생성 및 저장: ${_fcmToken!.substring(0, 20)}...');
          print('새 FCM 토큰(전체): $_fcmToken');

        }
      }

      // 토큰 갱신 리스너 설정
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('FCM 토큰 갱신: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        state = newToken; // 상태 업데이트

        // SecureStorage 업데이트
        await _storage.write(key: 'fcm_token', value: newToken);
        print('FCM 토큰 갱신 후 저장 완료');

        // 로그인 상태라면 서버에 새 토큰 전송
        final accessToken = await _tokenRepository.getAccessToken();
        if (accessToken != null) {
          await _sendTokenToServer(newToken);
        }
      });

    } catch (e) {
      print('FCM 토큰 생성 실패: $e');
    }
  }

  /// 서버에 FCM 토큰 전송 (JWT 인증 사용)
  Future<void> _sendTokenToServer(String token) async {
    try {
      // api 생성되면 주석 제거
      print('FCM Token을 서버로 전달하는 함수');
      // // TokenRepository를 통해 JWT Access Token 가져오기
      // final accessToken = await _tokenRepository.getAccessToken();
      // print('accessToken : ${accessToken}');
      //
      // if (accessToken != null) {
      //   final response = await _dio.post(
      //     '/api/fcm/register-token', // 실제 FCM 토큰 등록 API
      //     data: {
      //       'fcmToken': token,
      //       'timestamp': DateTime.now().toIso8601String(),
      //     },
      //     options: Options(
      //       headers: {
      //         // 'Authorization': 'Bearer $accessToken', //  JWT 토큰을 Authorization 헤더에 포함
      //         'Content-Type': 'application/json',
      //       },
      //     ),
      //   );
      //
      //   if (response.statusCode == 200) {
      //     print('JWT 인증으로 FCM 토큰 서버 전송 완료');
      //   } else {
      //     print('서버 응답 오류: ${response.statusCode}');
      //   }
      // } else {
      //   print('JWT 토큰이 없음 - 로그인 후 FCM 토큰 전송 필요');
      //   // 로그인 필요 상태 처리
      //   _handleLoginRequired();
      // }
    } catch (e) {
      print('FCM 토큰 서버 전송 실패: $e');
      print('테스트로 인해 재시도는 안함');
      // 재시도 로직 추가 가능
      //await _retryTokenSend(token);
    }
  }

  /// 로그인 필요 상태 처리
  void _handleLoginRequired() {
    // 로그인 화면으로 리다이렉트하거나
    // 나중에 전송하도록 스케줄링
    print('로그인 후 FCM 토큰 전송이 필요합니다');
  }

  /// FCM 토큰 전송 재시도
  Future<void> _retryTokenSend(String token) async {
    await Future.delayed(const Duration(seconds: 5));
    print('FCM 토큰 전송 재시도...');
    await _sendTokenToServer(token);
  }

  /// 'all_users' 토픽 구독
  Future<void> _subscribeToTopic() async {
    try {
      await _firebaseMessaging.subscribeToTopic('all_users');
      print('all_users 토픽 구독 완료');
    } catch (e) {
      print('토픽 구독 실패: $e');
    }
  }

  /// 메시지 리스너 설정
  void _setupMessageHandlers() {
    // 앱이 실행 중일 때 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 알림 수신: ${message.notification?.title}');
      print('message :  ${message.toMap()}');

      _showNotification(message); // 로그
      _showCustomNotification(message); // 커스텀 ui
    });

    // 알림을 탭해서 앱이 열렸을 때
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('백그라운드에서 알림 탭: ${message.notification?.title}');
      print('message :  ${message.toMap()}');

      _handleNotificationTap(message);
    });

    // 앱이 종료된 상태에서 알림을 탭해서 열었을 때
    _checkInitialMessage();
  }

  /// 앱이 종료된 상태에서 알림으로 열렸는지 확인
  Future<void> _checkInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('앱 종료 상태에서 알림 탭으로 앱 열림: ${initialMessage.notification?.title}');
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      print('초기 메시지 확인 실패: $e');
    }
  }

  /// 앱 실행 중일 때 알림 표시
  void _showNotification(RemoteMessage message) {
    print('알림 제목: ${message.notification?.title}');
    print('알림 내용: ${message.notification?.body}');
    print('추가 데이터: ${message.data}');

    // 여기서 로컬 알림을 표시하거나
    // 앱 내 알림 UI를 업데이트할 수 있습니다
  }

  /// 알림을 탭했을 때 처리
  void _handleNotificationTap(RemoteMessage message) {
    String? notificationType = message.data['type'];

    print('noti type : ${notificationType}');

    switch (notificationType) {
      case 'car_inspection':
        print('차량 점검 화면으로 이동');
        // UI 완성 시 추후 등록 예정
        break;
      case 'part_replacement':
        print('부품 교체 화면으로 이동');
        // UI 완성 시 추후 등록 예정
        break;
      default:
        print('메인 화면으로 이동');
      // UI 완성 시 추후 등록 예정
    }
  }

  /// 커스텀 알림 UI 표시
  void _showCustomNotification(RemoteMessage message) {
    showOverlayNotification(
          (context) {
        return CustomNotificationCard(
          title: message.notification?.title ?? '알림',
          body: message.notification?.body ?? '내용',
          onTap: () {
            OverlaySupportEntry.of(context)?.dismiss();
            _handleNotificationTap(message);
          },
          onDismiss: () {
            OverlaySupportEntry.of(context)?.dismiss();
          },
        );
      },
      duration: const Duration(seconds: 4), // 4초 후 자동 사라짐
    );
  }

  /// 로그인 후 FCM 토큰 서버 전송
  Future<void> sendTokenAfterLogin() async {

    if (_fcmToken == null) {
      print('토큰이 없어서 생성 중...');
      await _generateToken();

    }

    if (_fcmToken != null) {
      print('로그인 후 FCM 토큰 전송 시도...');

      await _sendTokenToServer(_fcmToken!);
      await _subscribeToTopic();

      print('로그인 후 FCM 완전 활성화 완료');
    } else {
      print('FCM 토큰이 생성되지 않았습니다');
    }
  }

  /// 로그아웃 시 토픽 구독 해제
  Future<void> handleLogout() async {
    try {
      // 토픽 구독 해제
      if (_fcmToken != null) {
        await _firebaseMessaging.unsubscribeFromTopic('all_users');
        print('토픽 구독 해제 완료');
      }

      print('로그아웃 - 토픽 구독 해제 (토큰 유지)');
    } catch (e) {
      print('토픽 구독 해제 실패: $e');
    }
  }

  /// FCM 토큰 완전 삭제 (앱 삭제 시에만 사용)
  Future<void> deleteTokenCompletely() async {
    try {
      // SecureStorage에서 삭제
      await _storage.delete(key: 'fcm_token');

      // 메모리에서 삭제
      _fcmToken = null;
      state = null;

      // 토픽 구독 해제
      await _firebaseMessaging.unsubscribeFromTopic('all_users');

      // 토픽 완전 삭제
      await FirebaseMessaging.instance.deleteToken();

      print('🗑FCM 토큰 완전 삭제 완료');
    } catch (e) {
      print('FCM 토큰 완전 삭제 실패: $e');
    }
  }

  /// 현재 FCM 토큰 반환
  String? get currentToken => _fcmToken;
}