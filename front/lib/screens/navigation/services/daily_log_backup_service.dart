// lib/screens/navigation/services/daily_log_backup_service.dart
import 'package:flutter/cupertino.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DailyLogBackupService {
  static const String DAILY_BACKUP_TASK = 'daily_backup_task';
  static const String WEEKLY_CLEANUP_TASK = 'weekly_cleanup_task';
  
  // SecureStorage 인스턴스 (백그라운드에서 사용)
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // 백그라운드 작업 초기화 (활성화)
  static Future<void> initialize() async {
    // debugPrint('🚀 백그라운드 작업 초기화 시작');
    
    try {
      // WorkManager 초기화
      await Workmanager().initialize(
        callbackDispatcher, // 백그라운드에서 실행될 함수
        isInDebugMode: true, // 디버그 모드로 설정하여 로그 확인
      );

      // 매일 새벽 6시에 실행되도록 스케줄링
      await _scheduleDailyBackup();

      // 매주 일요일 새벽 3시에 일주일 이상 된 로그 정리
      await _scheduleWeeklyCleanup();
      
      debugPrint('✅ 백그라운드 작업 초기화 완료');
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 초기화 실패: $e');
    }
  }

  // 매일 새벽 2시 백업 스케줄링
  static Future<void> _scheduleDailyBackup() async {
    try {
      // 기존 작업 취소
      await Workmanager().cancelByUniqueName(DAILY_BACKUP_TASK);

      // 다음 새벽 2시 계산
      final now = DateTime.now();
      var nextBackupTime = DateTime(now.year, now.month, now.day, 6, 18); // 새벽 2시

      // 이미 새벽 2시가 지났다면 다음날 새벽 2시로 설정
      if (now.isAfter(nextBackupTime)) {
        nextBackupTime = nextBackupTime.add(Duration(days: 1));
      }

      final initialDelay = nextBackupTime.difference(now);

      // debugPrint('📅 다음 백업 시간: $nextBackupTime (${initialDelay.inHours}시간 ${initialDelay.inMinutes % 60}분 후)');

      // 매일 반복 작업 등록 (24시간마다)
      await Workmanager().registerPeriodicTask(
        DAILY_BACKUP_TASK,
        DAILY_BACKUP_TASK,
        frequency: Duration(hours: 24),
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected, // 인터넷 연결 필요
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      // debugPrint('✅ 매일 새벽 2시 백업 스케줄 등록 완료');
    } catch (e) {
      debugPrint('❌ 백업 스케줄 등록 실패: $e');
    }
  }

  // 매주 일요일 새벽 3시 정리 작업 스케줄링
  static Future<void> _scheduleWeeklyCleanup() async {
    try {
      // 기존 작업 취소
      await Workmanager().cancelByUniqueName(WEEKLY_CLEANUP_TASK);

      // 다음 일요일 새벽 3시 계산
      final now = DateTime.now();
      var nextCleanupTime = DateTime(now.year, now.month, now.day, 3, 0);
      
      // 다음 일요일 찾기 (일요일 = 7)
      final daysUntilSunday = (7 - now.weekday) % 7;
      if (daysUntilSunday == 0 && now.isAfter(nextCleanupTime)) {
        // 오늘이 일요일인데 이미 새벽 3시가 지났다면 다음 주 일요일
        nextCleanupTime = nextCleanupTime.add(Duration(days: 7));
      } else {
        nextCleanupTime = nextCleanupTime.add(Duration(days: daysUntilSunday));
      }

      final initialDelay = nextCleanupTime.difference(now);

      // debugPrint('📅 다음 정리 시간: $nextCleanupTime (${initialDelay.inDays}일 ${initialDelay.inHours % 24}시간 후)');

      // 매주 반복 작업 등록 (7일마다)
      await Workmanager().registerPeriodicTask(
        WEEKLY_CLEANUP_TASK,
        WEEKLY_CLEANUP_TASK,
        frequency: Duration(days: 7),
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.unmetered, // WiFi 환경에서만
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      // debugPrint('✅ 매주 일요일 새벽 3시 정리 스케줄 등록 완료');
    } catch (e) {
      debugPrint('❌ 정리 스케줄 등록 실패: $e');
    }
  }

  // 수동으로 백업 실행 (테스트용)
  static Future<void> runManualBackup() async {
    await _performDailyBackup();
  }

  // 수동으로 정리 실행 (테스트용)
  static Future<void> runManualCleanup() async {
    await _performWeeklyCleanup();
  }

  // 실제 백업 작업 수행
  static Future<void> _performDailyBackup() async {
    try {
      debugPrint('🌙 새벽 백업 작업 시작: ${DateTime.now()}');

      // 1. 어제 날짜 계산
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day);

      // 2. 로컬 로그 파일 로드
      final logs = await _loadDrivingLogs();

      // 3. 어제 로그만 필터링
      final yesterdayLogs = logs.where((log) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final logDate = DateTime(startTime.year, startTime.month, startTime.day);
          return logDate.isAtSameMomentAs(yesterdayDate);
        } catch (e) {
          debugPrint('⚠️ 잘못된 로그 데이터: $e');
          return false;
        }
      }).toList();

      // debugPrint('📊 어제(${yesterdayDate.month}/${yesterdayDate.day}) 로그: ${yesterdayLogs.length}개');

      if (yesterdayLogs.isNotEmpty) {
        // 4. 하루치 주행거리 합계 계산 (미터를 킬로미터로 변환)
        final totalDistanceKm = yesterdayLogs.fold(0.0, (sum, log) => 
            sum + ((log['totalDistance'] as num?)?.toDouble() ?? 0.0)) / 1000.0;

        debugPrint('📏 어제 총 주행거리: ${totalDistanceKm.toStringAsFixed(2)}km');

        // 5. 서버로 주행거리 전송
        final success = await _sendDailyDistanceToServer(totalDistanceKm, yesterdayLogs);

        if (success) {
          debugPrint('✅ 어제 주행거리 서버 전송 완료: ${totalDistanceKm.toStringAsFixed(2)}km');
        } else {
          debugPrint('❌ 서버 전송 실패, 다음에 재시도');
        }
      } else {
        debugPrint('📭 어제 주행 로그가 없음');
      }

    } catch (e) {
      debugPrint('❌ 백업 작업 실패: $e');
    }
  }

  // 일주일 이상 된 로그 정리 작업
  static Future<void> _performWeeklyCleanup() async {
    try {
      // debugPrint('🗑️ 주간 로그 정리 작업 시작: ${DateTime.now()}');

      // 1. 일주일 전 날짜 계산
      final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
      final cutoffDate = DateTime(oneWeekAgo.year, oneWeekAgo.month, oneWeekAgo.day);

      // 2. 로컬 로그 파일 로드
      final logs = await _loadDrivingLogs();
      final originalCount = logs.length;

      // 3. 일주일 이내 로그만 필터링
      final recentLogs = logs.where((log) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final logDate = DateTime(startTime.year, startTime.month, startTime.day);
          return logDate.isAfter(cutoffDate) || logDate.isAtSameMomentAs(cutoffDate);
        } catch (e) {
          debugPrint('⚠️ 잘못된 로그 데이터: $e');
          return false; // 잘못된 데이터는 삭제
        }
      }).toList();

      // 4. 정리된 로그 저장
      await _saveDrivingLogs(recentLogs);
      
      final deletedCount = originalCount - recentLogs.length;
      // debugPrint('✅ 로그 정리 완료: ${deletedCount}개 삭제, ${recentLogs.length}개 유지');

    } catch (e) {
      debugPrint('❌ 로그 정리 실패: $e');
    }
  }

  // 서버로 하루치 주행거리 전송 (기존 API 클라이언트 구조 활용)
  static Future<bool> _sendDailyDistanceToServer(double totalDistanceKm, List<Map<String, dynamic>> logs) async {
    try {
      if (totalDistanceKm <= 0) {
        debugPrint('⚠️ 주행거리가 0이므로 전송하지 않음');
        return true;
      }

      final vin = await _secureStorage.read(key: 'currentVin');

      if (vin == null || vin.isEmpty) {
        debugPrint('❌ VIN 정보를 찾을 수 없어서 전송 실패');
        return false;
      }

      // debugPrint('📤 서버로 주행거리 전송 중: VIN=$vin, 거리=${totalDistanceKm.toStringAsFixed(2)}km');

      // SecureStorage에서 토큰 가져오기 (기존 secure_storage.dart에서 사용하는 키로 변경)
      final accessToken = await _secureStorage.read(key: 'accessToken');
      
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('❌ 액세스 토큰이 없어서 전송 실패');
        return false;
      }

      // 기존 API 클라이언트와 동일한 설정으로 Dio 생성
      final options = BaseOptions(
        baseUrl: 'http://i13e101.p.ssafy.io:8080', // 기존 설정과 동일
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );
      final dio = Dio(options);

      // 주행거리 전송 (재시도 로직 포함) - driving_distance_service.dart와 동일한 방식
      for (int i = 0; i < 3; i++) {
        try {
          final success = await _sendSingleDistanceRequest(dio, vin, totalDistanceKm, accessToken);
          if (success) {
            return true;
          }

          if (i < 2) {
            debugPrint('🔄 주행 거리 전송 재시도 중... (${i + 1}/3)');
            await Future.delayed(Duration(seconds: 2 * (i + 1))); // 지수 백오프
          }
        } catch (e) {
          debugPrint('❌ 주행거리 전송 재시도 실패 (${i + 1}/3): $e');
          if (i == 2) {
            return false;
          }
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }

      return false;

    } catch (e) {
      debugPrint('❌ 서버 전송 실패: $e');
      return false;
    }
  }

  static Future<bool> _sendSingleDistanceRequest(Dio dio, String vin, double distanceInKm, String accessToken) async {
    try {
      final kmFormatted = distanceInKm.toStringAsFixed(2);

      // debugPrint('🚗 주행 거리 전송 중: VIN=$vin, 거리=${kmFormatted}km');

      // API 호출: /api/v1/cars/{vin}/{km} (DrivingDistanceService와 동일)
      final response = await dio.post(
        '/api/v1/cars/$vin/$kmFormatted',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      // DrivingDistanceService와 완전 동일한 응답 처리
      final raw = response.data;
      late Map<String, dynamic> jsonMap;

      if (raw is String) {
        jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map) {
        jsonMap = raw.cast<String, dynamic>();
      } else {
        throw FormatException('Unexpected response type: ${raw.runtimeType}');
      }

      // 성공 여부 확인 (DrivingDistanceService와 동일)
      final isSuccess = jsonMap['isSuccess'] as bool? ?? false;
      if (!isSuccess) {
        final message = jsonMap['message'] as String? ?? '주행 거리 전송 실패';
        debugPrint('❌ 주행 거리 전송 실패: $message');
        return false;
      }

      // debugPrint('✅ 주행 거리 전송 성공: VIN=$vin, 거리=${kmFormatted}km');
      return true;

    } catch (e) {
      debugPrint('❌ 주행 거리 전송 중 오류 발생: $e');
      return false;
    }
  }

  // 로그 파일 로드
  static Future<List<Map<String, dynamic>>> _loadDrivingLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/driving_logs.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ 로그 로드 실패: $e');
      return [];
    }
  }

  // 로그 파일 저장
  static Future<void> _saveDrivingLogs(List<Map<String, dynamic>> logs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/driving_logs.json');

      final jsonString = jsonEncode(logs);
      await file.writeAsString(jsonString);

      // debugPrint('💾 로그 파일 저장 완료: ${logs.length}개');
    } catch (e) {
      debugPrint('❌ 로그 저장 실패: $e');
    }
  }

  // 저장된 로그 상태 확인 (디버그용)
  static Future<Map<String, dynamic>> getLogStatus() async {
    try {
      final logs = await _loadDrivingLogs();
      final now = DateTime.now();
      
      // 날짜별 로그 개수 계산
      Map<String, int> logsByDate = {};
      double totalDistance = 0.0;
      
      for (final log in logs) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final dateKey = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
          logsByDate[dateKey] = (logsByDate[dateKey] ?? 0) + 1;
          
          final distance = (log['totalDistance'] as num?)?.toDouble() ?? 0.0;
          totalDistance += distance;
        } catch (e) {
          // 잘못된 데이터는 무시
        }
      }

      return {
        'totalLogs': logs.length,
        'totalDistanceKm': (totalDistance / 1000).toStringAsFixed(2),
        'logsByDate': logsByDate,
        'oldestLogDate': logs.isNotEmpty 
            ? logs.map((log) => DateTime.parse(log['startTime'])).reduce((a, b) => a.isBefore(b) ? a : b).toString()
            : null,
        'newestLogDate': logs.isNotEmpty 
            ? logs.map((log) => DateTime.parse(log['startTime'])).reduce((a, b) => a.isAfter(b) ? a : b).toString()
            : null,
      };
    } catch (e) {
      debugPrint('❌ 로그 상태 확인 실패: $e');
      return {'error': e.toString()};
    }
  }

  // 즉시 백업 실행 (디버그용)
  static Future<void> performImmediateBackup() async {
    debugPrint('🔄 즉시 백업 실행 중...');
    await _performDailyBackup();
  }

  // 즉시 정리 실행 (디버그용)
  static Future<void> performImmediateCleanup() async {
    debugPrint('🔄 즉시 정리 실행 중...');
    await _performWeeklyCleanup();
  }

  // 서버 연결 테스트 (디버그용) - 실제 데이터 전송하지 않음
  static Future<void> testServerConnection() async {
    debugPrint('🧪 서버 연결 테스트 시작 (DRY RUN)');
    
    try {
      const secureStorage = FlutterSecureStorage();
      final vin = await secureStorage.read(key: 'currentVin');
      final accessToken = await secureStorage.read(key: 'accessToken');
      
      // debugPrint('🔑 테스트 VIN: $vin');
      // debugPrint('🔑 테스트 토큰: ${accessToken != null ? "있음 (${accessToken.length}자)" : "없음"}');
      
      if (vin == null || vin.isEmpty) {
        debugPrint('❌ VIN이 없어서 테스트 불가');
        return;
      }
      
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('❌ 액세스 토큰이 없어서 테스트 불가');
        return;
      }
      
      // 실제 전송하지 않고 연결만 테스트
      // debugPrint('🌐 서버 연결 상태 확인 중...');
      
      final options = BaseOptions(
        baseUrl: 'http://i13e101.p.ssafy.io:8080',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      );
      final dio = Dio(options);
      
      try {
        // HEAD 요청으로 서버 상태만 확인 (실제 데이터 전송 안함)
        final response = await dio.get(
          '/api/v1/health', // 헬스체크 엔드포인트 (있다면)
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          ),
        );
        
        // debugPrint('✅ 서버 연결 테스트 성공! (상태: ${response.statusCode})');
        // debugPrint('💡 주의: 실제 주행거리는 전송되지 않았습니다.');
        
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          // 헬스체크 엔드포인트가 없다면 인증만 확인
          // debugPrint('✅ 서버 연결 및 인증 토큰 유효함 (404는 정상 - 헬스체크 엔드포인트 없음)');
        } else {
          debugPrint('❌ 서버 연결 테스트 실패: $e');
        }
      }
      
    } catch (e) {
      debugPrint('❌ 서버 연결 테스트 오류: $e');
    }
  }
  
  // 실제 주행거리 전송 테스트 (주의: 실제 데이터가 전송됨!)
  static Future<void> testActualDataSending() async {
    // debugPrint('⚠️ 실제 데이터 전송 테스트 시작 - 주의: 서버에 실제 반영됨!');
    
    try {
      const secureStorage = FlutterSecureStorage();
      final vin = await secureStorage.read(key: 'currentVin');
      final accessToken = await secureStorage.read(key: 'accessToken');
      
      if (vin == null || vin.isEmpty || accessToken == null || accessToken.isEmpty) {
        debugPrint('❌ VIN 또는 토큰이 없어서 테스트 불가');
        return;
      }
      
      // 0.01km로 실제 테스트 전송
      final testDistance = 0.01;
      // debugPrint('📤 실제 테스트 전송: ${testDistance}km (서버에 반영됨!)');
      
      final options = BaseOptions(
        baseUrl: 'http://i13e101.p.ssafy.io:8080',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      );
      final dio = Dio(options);
      
      final success = await _sendSingleDistanceRequest(dio, vin, testDistance, accessToken);
      
      if (success) {
        // debugPrint('✅ 실제 데이터 전송 테스트 성공!');
        // debugPrint('⚠️ 주의: 0.01km가 실제로 서버에 추가되었습니다!');
      } else {
        debugPrint('❌ 실제 데이터 전송 테스트 실패');
      }
      
    } catch (e) {
      debugPrint('❌ 실제 데이터 전송 테스트 오류: $e');
    }
  }
}
// 백그라운드에서 실행될 콜백 함수
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // debugPrint('🌙 백그라운드 작업 실행: $task');

    switch (task) {
      case DailyLogBackupService.DAILY_BACKUP_TASK:
        await DailyLogBackupService._performDailyBackup();
        break;
      case DailyLogBackupService.WEEKLY_CLEANUP_TASK:
        await DailyLogBackupService._performWeeklyCleanup();
        break;
    }

    return Future.value(true);
  });
}
