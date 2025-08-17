import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:moring/models/unread_notification.dart';

class NotificationApi {
  final Dio _dio;
  NotificationApi(this._dio);

  /// GET /api/v1/notifications/{vin}/count
  Future<int> fetchUnreadCount(String vin) async {
    final resp = await _dio.get('/api/v1/notifications/$vin/count');
    return (resp.data['result'] as num).toInt();
  }

  /// GET /api/v1/notifications/{vin}/unread
  Future<Map<String, dynamic>> fetchUnreadNotifications({
    required String vin,
    int page = 0,
    int size = 10,
  }) async {
    final resp = await _dio.get(
      '/api/v1/notifications/$vin/unread',
      queryParameters: {'page': page, 'size': size},
    );
    
    // API 응답 구조: { result: { content: [...], last: bool, empty: bool, numberOfElements: int } }
    final result = resp.data['result'] as Map<String, dynamic>;
    final content = (result['content'] as List).cast<Map<String, dynamic>>();
    final notifications = content
        .map((e) => UnreadNotification.fromJson(e))
        .toList();
    
    return {
      'notifications': notifications,
      'last': result['last'] ?? false,
      'empty': result['empty'] ?? true,
      'numberOfElements': result['numberOfElements'] ?? 0,
    };
  }

  /// PATCH /api/v1/notifications/read/{notificationId}
  Future<bool> fetchReadNotification({required int id})async {
    final resp = await _dio.patch(
        '/api/v1/notifications/read/$id'
    );
    if (resp.statusCode == 200) {
      debugPrint('✅PATCH 성공 : $id 알림 확인');
      return true;
    } else {
      debugPrint('❗PATCH 실패 : $id 알림 미확인');
      return false;
    }
  }

  /// PATCH /api/v1/notifications/{vin}/read-all
  Future<void> fetchReadAllNotification({required String vin})async {
    final resp = await _dio.patch(
        '/api/v1/notifications/$vin/read-all'
    );
    if (resp.statusCode == 200) {
      debugPrint('✅PATCH 성공 : $vin 알림 전부 확인');
    } else {
      debugPrint('❗PATCH 실패 : $vin 알림 전부 미확인');
    }
  }
}
