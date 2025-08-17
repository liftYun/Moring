import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';

class DrivingStatusService {
  final Dio _dio;

  DrivingStatusService(this._dio);

  /// 차량의 운전 상태를 서버에 업데이트
  /// [vin] 차량 VIN
  /// [isDriving] 운전 중 상태 여부 (true: 운전 중, false: 정지)
  Future<bool> updateDrivingStatus(String vin, bool isDriving) async {
    try {
      final response = await _dio.patch(
        '/api/v1/cars/$vin/driving-status',
        queryParameters: {
          'isDriving': isDriving,
        },
      );

      if (response.statusCode == 200) {
        print('✅ 운전 상태 업데이트 성공: VIN=$vin, isDriving=$isDriving');
        return true;
      } else {
        print('❌ 운전 상태 업데이트 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 운전 상태 업데이트 오류: $e');
      return false;
    }
  }
}

// Provider 생성
final drivingStatusServiceProvider = Provider<DrivingStatusService>((ref) {
  final dio = ref.watch(authDioProvider);
  return DrivingStatusService(dio);
});
