import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:moring/providers/api_client.dart';

import 'dart:io';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    final tokenRepo = ref.read(tokenRepositoryProvider);
    final dio = ref.read(noAuthDioProvider);
    try {
      final canTalk = await isKakaoTalkInstalled();
      final oauth = canTalk
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();

      final resp = await dio.get(
        '/api/kakao/redirect',
        options: Options(
          headers: {'Authorization': 'Bearer ${oauth.accessToken}'},
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      // Set-Cookie 에서 refreshToken 꺼내기
      // Set-Cookie 헤더 중 'refreshToken' 쿠키만 골라서 순수 값만 저장
      final setCookieHeaders = resp.headers['set-cookie'];
      if (setCookieHeaders != null) {
        for (final header in setCookieHeaders) {
          // 'refreshToken=' 으로 시작하는 쿠키만 골라 파싱
          if (header.trim().startsWith('refreshToken=')) {
            final cookie = Cookie.fromSetCookieValue(header);
            final tokenValue = cookie.value;
            await tokenRepo.saveRefreshToken(tokenValue);
            break;
          }
        }
      }

      final data = resp.data;
      final access = data['accessToken'] as String?;
      if (access != null) {
        await tokenRepo.saveAccessToken(access);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다.')),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('카카오 로그인'),
          onPressed: _loading ? null : _login,
        ),
      ),
    );
  }
}
