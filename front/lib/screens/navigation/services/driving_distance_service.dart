import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/current_car_provider.dart';

/// 주행 거리 전송 서비스 프로바이더
final drivingDistanceServiceProvider = Provider<DrivingDistanceService>((ref) {
  final dio = ref.read(authDioProvider);
  return DrivingDistanceService(dio, ref);
});

class DrivingDistanceService {
  final Dio _dio;
  final Ref _ref;
  
  DrivingDistanceService(this._dio, this._ref);

  /// 주행 거리를 백엔드로 전송
  /// [distanceInKm] - 주행 거리 (킬로미터 단위)
  Future<bool> sendDrivingDistance(double distanceInKm) async {
    try {
      // 현재 선택된 차량의 VIN 가져오기
      final currentCar = _ref.read(currentCarProvider);
      if (currentCar == null || currentCar.vin.isEmpty) {
        debugPrint('❌ 현재 차량 정보를 찾을 수 없습니다.');
        return false;
      }
      
      final vin = currentCar.vin;
      // 킬로미터를 소수점 둘째자리까지 포맷팅
      final kmFormatted = distanceInKm.toStringAsFixed(2);
      
      debugPrint('🚗 주행 거리 전송 중: VIN=$vin, 거리=${kmFormatted}km');
      
      // API 호출: /api/v1/cars/{vin}/{km}
      final response = await _dio.post('/api/v1/cars/$vin/$kmFormatted');
      
      // 응답 처리
      final raw = response.data;
      late Map<String, dynamic> jsonMap;
      
      if (raw is String) {
        jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map) {
        jsonMap = raw.cast<String, dynamic>();
      } else {
        throw FormatException('Unexpected response type: ${raw.runtimeType}');
      }
      
      // 성공 여부 확인
      final isSuccess = jsonMap['isSuccess'] as bool? ?? false;
      if (!isSuccess) {
        final message = jsonMap['message'] as String? ?? '주행 거리 전송 실패';
        debugPrint('❌ 주행 거리 전송 실패: $message');
        return false;
      }
      
      debugPrint('✅ 주행 거리 전송 성공: VIN=$vin, 거리=${kmFormatted}km');
      return true;
      
    } catch (e) {
      debugPrint('❌ 주행 거리 전송 중 오류 발생: $e');
      return false;
    }
  }
  
  /// 주행 거리 전송 (재시도 포함)
  /// [distanceInKm] - 주행 거리 (킬로미터 단위)
  /// [retryCount] - 재시도 횟수 (기본값: 3)
  Future<bool> sendDrivingDistanceWithRetry(
    double distanceInKm, {
    int retryCount = 3,
  }) async {
    for (int i = 0; i < retryCount; i++) {
      try {
        final success = await sendDrivingDistance(distanceInKm);
        if (success) {
          return true;
        }
        
        if (i < retryCount - 1) {
          debugPrint('🔄 주행 거리 전송 재시도 중... (${i + 1}/$retryCount)');
          await Future.delayed(Duration(seconds: 2 * (i + 1))); // 지수 백오프
        }
      } catch (e) {
        debugPrint('❌ 주행 거리 전송 재시도 실패 (${i + 1}/$retryCount): $e');
        if (i == retryCount - 1) {
          return false;
        }
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    
    return false;
  }
}
