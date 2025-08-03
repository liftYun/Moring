import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moring/providers/token_repository.dart';

part 'api_client.g.dart';

class _QueuedRequest {
  RequestOptions requestOptions;
  Completer<Response> completer;
  _QueuedRequest(this.requestOptions) : completer = Completer<Response>();
}

@riverpod
Dio authDio(AuthDioRef ref) {
  final repo = ref.read(tokenRepositoryProvider);

  final options = BaseOptions(
    // 로컬 테스트시 사용
    // baseUrl: Platform.isAndroid
    //     ? 'http://10.0.2.2:8080'
    //     : 'http://localhost:8080',
    // 서버 배포 주소로 요청
    baseUrl: 'http://i13e101.p.ssafy.io:8080',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  final dio = Dio(options);
  bool isRefreshing = false;
  final queue = <_QueuedRequest>[];

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // 모든 요청에 AT 붙이기
      final token = await repo.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (err, handler) async {
      // 1) 401 Unauthorized 감지 (AT 만료)
      if (err.response?.statusCode == 401) {
        // 2) 리프레시 중복 호출 방지
        final opts = err.requestOptions;

        // 큐에 이 요청을 넣고, 완료될 때까지 기다리도록 준비
        final queued = _QueuedRequest(opts);
        queue.add(queued);

        if (!isRefreshing) {
          isRefreshing = true;
          try {
            final refreshToken = await repo.getRefreshToken();
            if (refreshToken == null) throw Exception('No refresh token');

            // 3) 리프레시 API 호출 (쿠키 방식이라면 쿠키 헤더로)
            final refreshDio = Dio(options);
            final refreshResp = await refreshDio.post(
              '/api/v1/auth/refresh',
              options: Options(
                headers: {
                  'Cookie': 'refreshToken=$refreshToken',
                },
                validateStatus: (s) => s != null && s < 500,
              ),
            );

            if (refreshResp.statusCode == 200) {
              // 4) 새 액세스 토큰 저장
              final newAccess = refreshResp.data['accessToken'] as String?;
              if (newAccess != null) {
                await repo.saveAccessToken(newAccess);
              }

              // 큐에 모인 모든 요청 재시도
              for (var qr in queue) {
                // 원래 요청 옵션에 새 토큰 헤더를 붙이고
                qr.requestOptions.headers['Authorization'] =
                'Bearer $newAccess';
                // 실제 요청 보내기
                dio.fetch(qr.requestOptions)
                    .then((r) => qr.completer.complete(r))
                    .catchError((e) => qr.completer.completeError(e));
              }
            } else {
              // 리프레시 실패시 큐에 있는 요청 모두 에러 처리
              for (var qr in queue) {
                qr.completer.completeError(Exception('Refresh failed'));
              }
            }
          } catch (e) {
            // 토큰 갱신 중 에러 발생 시 큐 모두 에러
            for (var qr in queue) {
              qr.completer.completeError(e);
            }
          } finally {
            queue.clear();
            isRefreshing = false;
          }
        }

        // 이 요청의 결과를 큐에 달린 Future로 리턴
        return handler.resolve(await queued.completer.future);
      }
      // 401 이외 에러는 그대로 흘려보냄
      handler.next(err);
    }
  ));

  return dio;
}


@riverpod
Dio noAuthDio(NoAuthDioRef ref) {
  final options = BaseOptions(
    // 로컬 테스트시 사용
    // baseUrl: Platform.isAndroid
    //     ? 'http://10.0.2.2:8080'
    //     : 'http://localhost:8080',
    // 서버 배포 주소로 요청,
    baseUrl: 'http://i13e101.p.ssafy.io:8080',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  return Dio(options);
}
