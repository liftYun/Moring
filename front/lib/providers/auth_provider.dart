import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../main.dart';
import 'token_repository.dart';
import 'api_client.dart'; // noAuthDioProvider

part 'auth_provider.g.dart';

@riverpod
Future<bool> isLoggedIn(IsLoggedInRef ref) async {
  final repo = ref.read(tokenRepositoryProvider);

  // 1) 저장된 AT 꺼내오기
  final accessToken = await repo.getAccessToken();
  if (accessToken != null && accessToken.isNotEmpty) {
    // 2) AT 만료 안됐으면 OK
    if (!JwtDecoder.isExpired(accessToken)) {
      return true;
    }
  }

  // 3) AT가 없거나 만료되었으면 RT로 갱신 시도
  final refreshToken = await repo.getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    // RT도 없으면 로그인 상태 아님
    return false;
  }

  try {
    // noAuthDioProvider: 토큰 없이 쓰는 Dio
    final dio = ref.read(noAuthDioProvider);
    final resp = await dio.post(
      '/api/v1/auth/refresh',
      options: Options(
        headers: {'Cookie': 'refreshToken=$refreshToken'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (resp.statusCode == 200) {
      // 4) 갱신된 토큰 저장
      final newAccess = resp.data['accessToken'] as String?;
      final newRefresh = resp.data['refreshToken'] as String?;
      if (newAccess != null)  await repo.saveAccessToken(newAccess);
      if (newRefresh != null) await repo.saveRefreshToken(newRefresh);

      // 이제 로그인 상태로 본다
      return true;
    }
  } catch (_) {
    // 토큰 갱신 실패 시
    await repo.deleteAllTokens();          // 로컬에 저장된 토큰 삭제
    navigatorKey.currentState              // 로그인 화면으로
        ?.pushNamedAndRemoveUntil('/login', (r) => false);
  }

  // 5) 갱신 실패하면 로그인 아니라고 판단
  return false;
}
