import 'package:dio/dio.dart';

import '../providers/api_client.dart';

class NotificationApi {
  final Dio _dio;
  NotificationApi(this._dio);

  /// GET /notifications/{vin}/count
  Future<int> fetchUnreadCount(String vin) async {
    final resp = await _dio.get('/api/v1/notifications/$vin/count');
    // BaseResponse<Long> 형태라고 가정하면
    // { "success": true, "data": 5 }
    return (resp.data['data'] as num).toInt();
  }
}
