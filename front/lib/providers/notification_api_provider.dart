import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/notification_api_service.dart';
import 'api_client.dart'; // 여기서 authDioProvider를 정의했다고 가정

/// authDioProvider : Provider<Dio> 로 정의되어 있어야 합니다.
/// final authDioProvider = Provider<Dio>((ref) { ... });

final notificationApiProvider = Provider<NotificationApi>((ref) {
  final Dio authDio = ref.watch(authDioProvider);
  return NotificationApi(authDio);
});

final unreadCountProvider = StateProvider<int>((ref) => 0);
