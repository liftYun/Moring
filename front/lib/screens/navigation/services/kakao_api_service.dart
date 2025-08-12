import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_keys.dart';

class KakaoApiService {
  // REST API 키 (설정 파일에서 가져옴)
  static const String _restApiKey = ApiKeys.restApiKey;
  
  // 카카오 로컬 API - 주소 검색
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      debugPrint('🔍 주소 검색 시작: $query');
      debugPrint('🔑 REST API 키: $_restApiKey');
      
      // API URL 구성 (키워드 검색으로 변경)
      final url = 'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}';
      debugPrint('🌐 API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'KakaoAK $_restApiKey',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 API 응답 상태: ${response.statusCode}');
      debugPrint('📄 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        debugPrint('✅ 검색 결과: ${documents.length}개');
        
        return documents.map((doc) => {
          'placeName': doc['place_name'] ?? '알 수 없는 장소',
          'address': doc['address_name'] ?? '알 수 없는 주소',
          'roadAddress': doc['road_address_name'] ?? '',
          'latitude': double.parse(doc['y']),
          'longitude': double.parse(doc['x']),
        }).toList();
      } else {
        debugPrint('❌ API 오류: ${response.statusCode} - ${response.body}');
        throw Exception('주소 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 예외 발생: $e');
      throw Exception('주소 검색 오류: $e');
    }
  }

  // 카카오 길찾기 API - 경로 계산
  static Future<Map<String, dynamic>> getRoute(
    double startLat, double startLng,
    double endLat, double endLng,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://apis-navi.kakaomobility.com/v1/directions?'
          'origin=$startLng,$startLat&'
          'destination=$endLng,$endLat&'
          'waypoints=&'
          'avoid=&'
          'priority=RECOMMEND&'
          'car_fuel=GASOLINE&'
          'car_hipass=false&'
          'alternatives=false&'
          'road_details=false'
        ),
        headers: {
          'Authorization': 'KakaoAK $_restApiKey',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('kakao 길찾기 api response : ${response}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final route = routes[0];
          final sections = route['sections'] as List;
          
          List<Map<String, double>> coordinates = [];
          
          for (var section in sections) {
            final roads = section['roads'] as List;
            for (var road in roads) {
              final vertexes = road['vertexes'] as List;
              for (int i = 0; i < vertexes.length; i += 2) {
                coordinates.add({
                  'latitude': vertexes[i + 1].toDouble(),
                  'longitude': vertexes[i].toDouble(),
                });
              }
            }
          }
          
          // 교통 정보 추출
          String trafficInfo = '보통';
          int duration = 0;
          double distance = 0.0;
          
          for (var section in sections) {
            final sectionDuration = section['duration'];
            final sectionDistance = section['distance'];
            
            if (sectionDuration != null) {
              if (sectionDuration is int) {
                duration += sectionDuration;
              } else if (sectionDuration is num) {
                duration += sectionDuration.round();
              }
            }
            
            if (sectionDistance != null) {
              if (sectionDistance is double) {
                distance += sectionDistance;
              } else if (sectionDistance is num) {
                distance += sectionDistance.toDouble();
              }
            }
            
            // 교통 상황 확인 (간단한 로직)
            if (section['traffic'] != null) {
              trafficInfo = '혼잡';
            }
          }
          
          return {
            'coordinates': coordinates,
            'duration': duration, // 초 단위
            'distance': distance, // 미터 단위
            'traffic': trafficInfo,
          };
        }
      }
      
      throw Exception('경로 계산 실패: ${response.statusCode}');
    } catch (e) {
      throw Exception('경로 계산 오류: $e');
    }
  }
}
