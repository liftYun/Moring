import 'dart:io';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moring/providers/token_repository.dart';

part 'api_client.g.dart';

@riverpod
Dio authDio(AuthDioRef ref) {
  final repo = ref.read(tokenRepositoryProvider);
  final options = BaseOptions(
    baseUrl: Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  final dio = Dio(options)
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await repo.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          // 예: 리프레시 후 재시도 로직
          final refresh = await repo.getRefreshToken();
          if (refresh != null) {
            // TODO: refresh API 호출 및 토큰 갱신
            // await repo.saveAccessToken(newAccessToken);
            // 요청 재시도: return handler.resolve(await dio.fetch(e.requestOptions));
          }
        }
        return handler.next(e);
      },
    ));
  return dio;
}

@riverpod
Dio noAuthDio(NoAuthDioRef ref) {
  final options = BaseOptions(
    baseUrl: Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  );
  return Dio(options);
}
