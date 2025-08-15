// lib/providers/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:moring/main.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moring/providers/token_repository.dart';

part 'api_client.g.dart';

class _QueuedRequest {
  RequestOptions requestOptions;
  Completer<Response> completer;
  _QueuedRequest(this.requestOptions) : completer = Completer<Response>();
}

/// ===== JWT exp 디코드 유틸 =====
int? _jwtExpEpochSec(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload =
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
  } catch (_) {}
  return null;
}

/// ===== (내보내는) 선제 리프레시 함수 =====
/// - 만료까지 thresholdSec 이하로 남았으면 /auth/refresh 호출해서 토큰 교체
/// - refresh 요청 자체에는 Authorization 붙이지 않음(extras로 제어)
Future<void> ensureFreshAccessToken(
    Dio dio,
    TokenRepository repo, {
      int thresholdSec = 60,
    }) async {
  final at = await repo.getAccessToken();
  if (at == null) return;

  final exp = _jwtExpEpochSec(at);
  if (exp == null) return;

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (exp - nowSec > thresholdSec) return; // 아직 여유 있음

  final rt = await repo.getRefreshToken();
  if (rt == null) throw Exception('No refresh token');

  final resp = await dio.post(
    '/api/v1/auth/refresh',
    options: Options(
      headers: {
        'Cookie': 'refreshToken=$rt',
      },
      // refresh 호출엔 Auth/선제리프레시를 적용하지 않도록 마커 설정
      extra: {'skipAuth': true, 'skipPreRefresh': true},
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  if (resp.statusCode == 200) {
    final newAt = resp.data['accessToken'] as String?;
    final newRt = resp.data['refreshToken'] as String?;
    if (newAt != null) await repo.saveAccessToken(newAt);
    if (newRt != null) await repo.saveRefreshToken(newRt);
  } else {
    throw Exception('Pre-refresh failed (${resp.statusCode})');
  }
}

@riverpod
Dio authDio(AuthDioRef ref) {
  final repo = ref.read(tokenRepositoryProvider);

  final options = BaseOptions(
    // 위)로컬 테스트 / 아래)서버 테스트
    // baseUrl: Platform.isAndroid
    //     ? 'http://10.0.2.2:8080'
    //     : 'http://localhost:8080',
    baseUrl: 'https://i13e101.p.ssafy.io',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  final dio = Dio(options);
  bool isRefreshing = false;
  final queue = <_QueuedRequest>[];

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // refresh/self 호출은 선제리프레시/Authorization 스킵
      final extra = options.extra;
      final skipPre = extra['skipPreRefresh'] == true;
      final skipAuth = extra['skipAuth'] == true;

      // 1) 선제 리프레시 (만료 60초 이내면 갱신)
      if (!skipPre && !options.path.contains('/api/v1/auth/refresh')) {
        try {
          await ensureFreshAccessToken(dio, repo, thresholdSec: 60);
        } catch (_) {
          // 선제 갱신 실패는 그냥 지나감 → onError 401 로직에서 처리
        }
      }

      // 2) Authorization 주입
      if (!skipAuth) {
        final token = await repo.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }

      handler.next(options);
    },
    onError: (err, handler) async {
      debugPrint(
          '🔴 Dio onError: ${err.requestOptions.path} → ${err.response?.statusCode}');

      // refresh 호출 자체가 401이면 큐잉하지 말고 바로 로그아웃 처리
      if (err.requestOptions.path.contains('/api/v1/auth/refresh') &&
          err.response?.statusCode == 401) {
        await repo.deleteAllTokens();
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (r) => false);
        return handler.next(err);
      }

      // 1) 401 Unauthorized 감지 (AT 만료)
      if (err.response?.statusCode == 401 &&
          !err.requestOptions.path.contains('/api/v1/auth/refresh')) {
        // 큐에 이 요청을 넣고, 완료될 때까지 기다리도록 준비
        final opts = err.requestOptions;
        final queued = _QueuedRequest(opts);
        queue.add(queued);

        // 중복 리프레시 방지
        if (!isRefreshing) {
          isRefreshing = true;
          try {
            final refreshToken = await repo.getRefreshToken();
            if (refreshToken == null) throw Exception('No refresh token');
            debugPrint('🔄 리프레시 시도');

            final refreshResp = await dio.post(
              '/api/v1/auth/refresh',
              options: Options(
                headers: {'Cookie': 'refreshToken=$refreshToken'},
                extra: {'skipAuth': true, 'skipPreRefresh': true},
                validateStatus: (s) => s != null && s < 500,
              ),
            );

            if (refreshResp.statusCode == 200) {
              final newAccess = refreshResp.data['accessToken'] as String?;
              final newRefresh = refreshResp.data['refreshToken'] as String?;
              if (newAccess != null) await repo.saveAccessToken(newAccess);
              if (newRefresh != null) await repo.saveRefreshToken(newRefresh);

              // 큐에 모인 모든 요청 재시도
              for (var qr in queue) {
                // 원래 요청 옵션에 새 토큰 헤더를 붙이고
                final at = await repo.getAccessToken();
                if (at != null) {
                  qr.requestOptions.headers['Authorization'] = 'Bearer $at';
                } else {
                  qr.requestOptions.headers.remove('Authorization');
                }
                // 실제 요청 보내기
                dio
                    .fetch(qr.requestOptions)
                    .then((r) => qr.completer.complete(r))
                    .catchError((e) => qr.completer.completeError(e));
              }
            } else {
              throw Exception('Refresh failed (${refreshResp.statusCode})');
            }
          } catch (e) {
            // 토큰 갱신 실패 시
            await repo.deleteAllTokens(); // 로컬 토큰 삭제
            navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/login', (r) => false);
            // 큐에 있는 요청들 전부 에러 처리
            for (var qr in queue) {
              qr.completer.completeError(Exception('Refresh failed'));
            }
          } finally {
            queue.clear();
            isRefreshing = false;
          }
        }

        // 이 요청을 큐에 달린 Future 로 기다림
        return handler.resolve(await queued.completer.future);
      }

      handler.next(err);
    },
  ));

  return dio;
}

@riverpod
Dio noAuthDio(NoAuthDioRef ref) {
  final options = BaseOptions(
    // 위)로컬 테스트 / 아래)서버 테스트
    // baseUrl: Platform.isAndroid
    //     ? 'http://10.0.2.2:8080'
    //     : 'http://localhost:8080',
    baseUrl: 'https://i13e101.p.ssafy.io',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  return Dio(options);
}
