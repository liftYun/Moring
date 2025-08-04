import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';

final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  final dio = ref.read(noAuthDioProvider);
  final tokenRepo = ref.read(tokenRepositoryProvider);
  return SocialAuthService(dio, tokenRepo);
});

class SocialAuthService {
  SocialAuthService(this._dio, this._tokenRepo);
  final Dio _dio;
  final TokenRepository _tokenRepo;

  /// 카카오 로그인 → 인가 코드 → 서버 콜 → JWT 저장
  Future<void> loginWithKakao() async {
    const redirectUri = 'kakaob0c6ed29bed9644abb543aac61d3e0d6://oauth';
    // 1) 인가 코드 받기
    final authCode = await AuthCodeClient.instance.authorize(
      redirectUri: redirectUri,
    );

    // 2) 백엔드로 code 전송
    final resp = await _dio.get(
      '/api/kakao/redirect',
      queryParameters: {'code': authCode},
      options: Options(
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    // 3) Set-Cookie -> refreshToken
    final setCookie = resp.headers['set-cookie'] ?? [];
    for (final header in setCookie) {
      if (header.trim().startsWith('refreshToken=')) {
        final cookie = Cookie.fromSetCookieValue(header);
        await _tokenRepo.saveRefreshToken(cookie.value);
        break;
      }
    }

    // 4) body -> accessToken
    final access = resp.data['accessToken'] as String?;
    if (access != null) {
      await _tokenRepo.saveAccessToken(access);
    }
  }

  ///  구글 로그인 로직 분리
  Future<void> loginWithGoogle() async {
    // TODO: Google OAuth code
  }

  Future<void> loginWithTest() async {
    final resp = await _dio.get(
      '/api/v1/auth/login/test',
      options: Options(
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    // 3) Set-Cookie -> refreshToken
    final setCookie = resp.headers['set-cookie'] ?? [];
    for (final header in setCookie) {
      if (header.trim().startsWith('refreshToken=')) {
        final cookie = Cookie.fromSetCookieValue(header);
        await _tokenRepo.saveRefreshToken(cookie.value);
        break;
      }
    }

    // 4) body -> accessToken
    final access = resp.data['accessToken'] as String?;
    if (access != null) {
      await _tokenRepo.saveAccessToken(access);
    }
  }
}
