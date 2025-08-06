import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/api_client.dart';

/// 프로바이더로 등록
final carServiceProvider = Provider<CarService>((ref) {
  final dio = ref.read(authDioProvider);
  return CarService(dio);
});

class CarService {
  final Dio _dio;
  CarService(this._dio);

  /// 내 차량 목록 조회
  FutureOr<List<Car>> getMyCars(String uuid) async {
    // "/api/v1/cars/{memberUuid}/list" 엔드포인트 호출
    // final resp = await _dio.get('/api/v1/cars/$uuid/list');
    final resp = await _dio.get(
      '/api/v1/cars/$uuid/list',
      options: Options(
        headers: {
          // 컨트롤러의 @RequestHeader("memberUuid") 에 대응
          'memberUuid': uuid,
        },
      ),
    );

    // resp.data 가 String 또는 Map일 수 있으므로 통일
    final raw = resp.data;
    late Map<String, dynamic> jsonMap;

    if (raw is String) {
      jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      jsonMap = raw.cast<String, dynamic>();
    } else {
      throw FormatException('Unexpected response type: ${raw.runtimeType}');
    }

    // 실제 결과 배열은 `result` 필드에 들어 있다고 가정
    final dynamic maybeList = jsonMap['result'];
    if (maybeList is! List) {
      throw FormatException('Expected result to be a List, but was $maybeList');
    }

    // List<dynamic> → List<Car>
    final List<Car> cars = (maybeList)
        .map((e) {
      if (e is! Map) {
        throw FormatException('Each car entry must be a Map, but was $e');
      }
      // Map<String, dynamic> 으로 캐스트
      final map = (e).cast<String, dynamic>();
      // 모델에 정의된 fromJson 으로 변환
      return Car.fromJson(map);
    })
        .toList();

    return cars;
  }
}
