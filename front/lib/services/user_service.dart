import 'package:dio/dio.dart';
import 'package:moring/models/user_info.dart';
import 'package:moring/providers/token_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';

// provider 위치는 원하시는 곳에
final userServiceProvider = Provider<UserService>((ref) {
  final dio = ref.read(authDioProvider);
  return UserService(dio);
});

class UserService {
  UserService(this._dio);
  final Dio _dio;

  Future<UserInfo> getUserInfo() async {
    final resp = await _dio.get('/api/v1/members/mypage');
    // 200 OK 가 아닌 경우 자동 에러 발생
    return UserInfo.fromJson(resp.data as Map<String, dynamic>);
  }
}
