import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
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
    // 1) resp.data 를 Map<String, dynamic> 으로 통일
    final raw = resp.data;
    late Map<String, dynamic> jsonMap;
    if (raw is String) {
      jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      jsonMap = raw.cast<String, dynamic>();
    } else {
      throw FormatException('Unexpected response type: ${raw.runtimeType}');
    }

    // 2) 실제 프로필 정보가 담긴 Map 꺼내기
    final result = jsonMap['result'];
    if (result is! Map) {
      throw FormatException('`result` is not a Map: $result');
    }
    final Map<String, dynamic> payload = (result).cast<String, dynamic>();

    // 3) UserInfo 모델로 변환
    return UserInfo.fromJson(payload);
  }

  Future<void> updateNickName(String nickName) async {
    final resp = await _dio.patch('/api/v1/members/update/$nickName',);
    // resp.data 가 String 또는 Map 일 수 있으므로 통일
    final raw = resp.data;
    late Map<String, dynamic> jsonMap;
    if (raw is String) {
      jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      jsonMap = raw.cast<String, dynamic>();
    } else {
      throw FormatException('Unexpected response type: ${raw.runtimeType}');
    }

    // { httpStatus, isSuccess, message, code, result: null } 형태라고 가정
    final isSuccess = jsonMap['isSuccess'] as bool? ?? false;
    if (!isSuccess) {
      final msg = jsonMap['message'] as String? ?? '닉네임 업데이트 실패';
      throw Exception(msg);
    }
    // 성공 시 아무것도 반환하지 않고 완료
  }
}