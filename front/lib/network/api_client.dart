import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // 1) Secure Storage (토큰 보관용)
  static final _storage = const FlutterSecureStorage();

  static final BaseOptions _options = BaseOptions(
    baseUrl: Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    // validateStatus: ... 필요하다면 여기서도
  );

  static final noAuthDio = Dio(_options);

  // 2) BaseOptions 에 공통 설정
  // 3) 전역 Dio 인스턴스
  // static final Dio instance = Dio(_options);
  // 4) 요청할 때마다 헤더에 accessToken 자동 주입
  // ..interceptors.add(InterceptorsWrapper(
  // onRequest: (options, handler) async {
  // final token = await _storage.read(key: 'accessToken');
  // if (token != null) {
  // options.headers['Authorization'] = 'Bearer $token';
  // }
  // return handler.next(options);
  // },
  // onError: (e, handler) {
  // // ex) 401 감지 → refresh 로직, 재시도 등
  // return handler.next(e);
  // },
  // ));
  // 3) 전역 Dio
  // static final Dio instance = Dio(_options)
  static final authDio = Dio(_options)
  // 4) 요청할 때마다 헤더에 accessToken 자동 주입
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        // ex) 401 감지 → refresh 로직, 재시도 등
        return handler.next(e);
      },
    ));
}
