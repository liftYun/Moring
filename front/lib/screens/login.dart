import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_auth/kakao_flutter_sdk_auth.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    baseUrl: Platform.isAndroid
        ? 'http://10.0.2.2:8080'    // Android 에뮬레이터에서 호스트 머신의 로컬 서버
        : 'http://localhost:8080',  // iOS 시뮬레이터나 맥/윈도우 로컬 테스트
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      // 1) 카카오톡 설치 여부 확인 (최상위 함수)
      final bool canTalk = await isKakaoTalkInstalled();
      // 2) UserApi.instance 에서 로그인 메서드 호출
      final OAuthToken token = canTalk
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
      // 2) 백엔드로 인가 코드 또는 액세스 토큰 전송 (예: GET /api/kakao/redirect)
      final resp = await _dio.get(
        '/api/kakao/redirect',
        options: Options(
          headers: {'Authorization': 'Bearer ${token.accessToken}'},
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      // 3) 백엔드에서 Set-Cookie 헤더로 내려준 세션 쿠키 영속화
      final rawCookie = resp.headers.map['set-cookie']?.join('; ');
      if (rawCookie != null) {
        await _storage.write(key: 'session_cookie', value: rawCookie);
      }
      // 4) 로그인 성공 시 메인 화면으로 이동
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('카카오 로그인 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: _loading
              ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('카카오 로그인'),
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}
