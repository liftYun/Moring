import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driving_data.dart';
import 'driving_log_service.dart';

class DailyLogBackupService {
  static const String HOURLY_BACKUP_TASK = 'hourly_backup_task';
  static const String WEEKLY_CLEANUP_TASK = 'weekly_cleanup_task';
  static const String ONEOFF_WARMUP_TASK = 'oneoff_warmup_task';
  static const Duration BACKUP_INTERVAL = Duration(hours: 4);
  static const int MAX_RETRY_COUNT = 5;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> initialize() async {
    // debugPrint('🚀 4시간 주기 백업 서비스 초기화 시작');
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );

    await _scheduleHourlyBackup();
    await _scheduleWeeklyCleanup();
    await _scheduleOneOffWarmup();

    // debugPrint('✅ 4시간 주기 백업 서비스 초기화 완료');
  }

  static Future<void> _scheduleHourlyBackup() async {
    await Workmanager().cancelByUniqueName(HOURLY_BACKUP_TASK);
    // debugPrint('📅 4시간 주기 백업 스케줄 등록 중...');

    await Workmanager().registerPeriodicTask(
      HOURLY_BACKUP_TASK,
      HOURLY_BACKUP_TASK,
      frequency: BACKUP_INTERVAL,
      initialDelay: const Duration(seconds: 10),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    debugPrint('✅ 4시간 주기 백업 스케줄 등록 완료');
  }

  // 첫 실행 보장용 OneOff
  static Future<void> _scheduleOneOffWarmup() async {
    await Workmanager().cancelByUniqueName(ONEOFF_WARMUP_TASK);
    // debugPrint('⚡ One-off 워밍업 작업 등록 (즉시 1회)');

    await Workmanager().registerOneOffTask(
      ONEOFF_WARMUP_TASK,
      ONEOFF_WARMUP_TASK,
      // initialDelay: Duration.zero,
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  static Future<void> _scheduleWeeklyCleanup() async {
    await Workmanager().cancelByUniqueName(WEEKLY_CLEANUP_TASK);

    final now = DateTime.now();
    var nextCleanupTime = DateTime(now.year, now.month, now.day, 3, 0);
    final daysUntilSunday = (7 - now.weekday) % 7;
    if (daysUntilSunday == 0 && now.isAfter(nextCleanupTime)) {
      nextCleanupTime = nextCleanupTime.add(const Duration(days: 7));
    } else {
      nextCleanupTime = nextCleanupTime.add(Duration(days: daysUntilSunday));
    }
    final initialDelay = nextCleanupTime.difference(now);

    // debugPrint('📅 다음 정리 시간: $nextCleanupTime');

    await Workmanager().registerPeriodicTask(
      WEEKLY_CLEANUP_TASK,
      WEEKLY_CLEANUP_TASK,
      frequency: const Duration(days: 7),
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    // debugPrint('✅ 매주 일요일 새벽 3시 정리 스케줄 등록 완료');
  }

  // ===== 실행 로직 =====

  static Future<void> runManualBackup() async {
    await _performHourlyBackup();
  }

  static Future<void> runManualCleanup() async {
    await _performWeeklyCleanup();
  }

  static Future<void> _performHourlyBackup() async {
    try {
      // debugPrint('⏰ 4시간 주기 백업 작업 시작: ${DateTime.now()}');
      final unsentLogs = await DrivingLogService.getUnsentLogs();
      // debugPrint('📤 전송 대기 중인 로그: ${unsentLogs.length}개');

      if (unsentLogs.isEmpty) return;

      final validLogs = unsentLogs.where((log) => log.retryCount < MAX_RETRY_COUNT).toList();
      final exceededLogs = unsentLogs.where((log) => log.retryCount >= MAX_RETRY_COUNT).toList();

      for (final log in exceededLogs) {
        await DrivingLogService.updateLogSentStatus(log, true, newRetryCount: log.retryCount);
      }
      if (validLogs.isEmpty) return;

      int successCount = 0;
      int failureCount = 0;

      for (final log in validLogs) {
        try {
          final distanceInKm = log.totalDistance / 1000;
          if (distanceInKm <= 0) {
            await DrivingLogService.updateLogSentStatus(log, true);
            successCount++;
            continue;
          }
          final ok = await _sendSingleLogToServer(log, distanceInKm);
          if (ok) {
            await DrivingLogService.updateLogSentStatus(log, true);
            successCount++;
          } else {
            await DrivingLogService.updateLogSentStatus(log, false, newRetryCount: log.retryCount + 1);
            failureCount++;
          }
          if (validLogs.length > 1) {
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (_) {
          await DrivingLogService.updateLogSentStatus(log, false, newRetryCount: log.retryCount + 1);
          failureCount++;
        }
      }

      debugPrint('📊 4시간 주기 백업 완료: 성공 $successCount개, 실패 $failureCount개');
    } catch (e) {
      debugPrint('❌ 4시간 주기 백업 작업 실패: $e');
    }
  }

  static Future<bool> _sendSingleLogToServer(DrivingData log, double distanceInKm) async {
    try {
      final vin = await _secureStorage.read(key: 'currentVin');
      final accessToken = await _secureStorage.read(key: 'accessToken');
      if ((vin ?? '').isEmpty || (accessToken ?? '').isEmpty) return false;

      final dio = Dio(BaseOptions(
        baseUrl: 'http://i13e101.p.ssafy.io:8080',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final kmFormatted = distanceInKm.toStringAsFixed(2);

      final response = await dio.post(
        '/api/v1/cars/$vin/$kmFormatted',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final raw = response.data;
      final Map<String, dynamic> jsonMap = switch (raw) {
        String s => jsonDecode(s) as Map<String, dynamic>,
        Map m => m.cast<String, dynamic>(),
        _ => throw FormatException('Unexpected response type: ${raw.runtimeType}')
      };

      return jsonMap['isSuccess'] as bool? ?? false;
    } catch (e) {
      debugPrint('❌ 서버 전송 중 오류: $e');
      return false;
    }
  }

  static Future<void> _performWeeklyCleanup() async {
    try {
      // debugPrint('🗑️ 주간 로그 정리 작업 시작: ${DateTime.now()}');
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final cutoffDate = DateTime(oneWeekAgo.year, oneWeekAgo.month, oneWeekAgo.day);
      final logs = await _loadDrivingLogs();
      final recentLogs = logs.where((log) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final logDate = DateTime(startTime.year, startTime.month, startTime.day);
          return !logDate.isBefore(cutoffDate);
        } catch (_) {
          return false;
        }
      }).toList();
      await _saveDrivingLogs(recentLogs);
      debugPrint('✅ 로그 정리 완료: 삭제 ${logs.length - recentLogs.length}개, 유지 ${recentLogs.length}개');
    } catch (e) {
      debugPrint('❌ 로그 정리 실패: $e');
    }
  }

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

  static Future<void> _saveDrivingLogs(List<Map<String, dynamic>> logs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/driving_logs.json');
      await file.writeAsString(jsonEncode(logs));
      // debugPrint('💾 로그 파일 저장 완료: ${logs.length}개');
    } catch (e) {
      debugPrint('❌ 로그 저장 실패: $e');
    }
  }

  static Future<Map<String, dynamic>> getLogStatus() async {
    try {
      final logs = await _loadDrivingLogs();
      double totalDistance = 0.0;
      final Map<String, int> logsByDate = {};
      for (final log in logs) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final dateKey = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
          logsByDate[dateKey] = (logsByDate[dateKey] ?? 0) + 1;
          totalDistance += ((log['totalDistance'] as num?)?.toDouble() ?? 0.0);
        } catch (_) {}
      }
      final oldest = logs.isNotEmpty ? logs.map((l) => DateTime.parse(l['startTime'])).reduce((a,b)=>a.isBefore(b)?a:b).toString() : null;
      final newest = logs.isNotEmpty ? logs.map((l) => DateTime.parse(l['startTime'])).reduce((a,b)=>a.isAfter(b)?a:b).toString() : null;

      final stats = await DrivingLogService.getTransmissionStats();
      return {
        'totalLogs': logs.length,
        'totalDistanceKm': (totalDistance / 1000).toStringAsFixed(2),
        'logsByDate': logsByDate,
        'oldestLogDate': oldest,
        'newestLogDate': newest,
        'transmissionStats': stats,
      };
    } catch (e) {
      debugPrint('❌ 로그 상태 확인 실패: $e');
      return {'error': e.toString()};
    }
  }

  static Future<void> performImmediateBackup() async {
    // debugPrint('🔄 즉시 4시간 주기 백업 실행 중...');
    await _performHourlyBackup();
  }

  static Future<void> performImmediateCleanup() async {
    // debugPrint('🔄 즉시 정리 실행 중...');
    await _performWeeklyCleanup();
  }

  static Future<void> resetRetryCountsForAllLogs() async {
    try {
      final allLogs = await DrivingLogService.loadDrivingLogs();
      final updated = allLogs.map((e) => e.copyWith(retryCount: 0, isSentToServer: false)).toList();
      await DrivingLogService.saveDrivingLogsList(updated);
    } catch (e) {
      debugPrint('❌ 재시도 횟수 초기화 실패: $e');
    }
  }

  static Future<void> testServerConnection() async {
    // debugPrint('🧪 서버 연결 테스트 시작 (DRY RUN)');
    try {
      final vin = await _secureStorage.read(key: 'currentVin');
      final accessToken = await _secureStorage.read(key: 'accessToken');
      if ((vin ?? '').isEmpty || (accessToken ?? '').isEmpty) return;
      final dio = Dio(BaseOptions(
        baseUrl: 'http://i13e101.p.ssafy.io:8080',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      try {
        final resp = await dio.get(
          '/api/v1/health',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        // debugPrint('✅ 서버 연결 테스트 성공: ${resp.statusCode}');
      } catch (e) {
        debugPrint('ℹ️ 헬스체크 엔드포인트 없을 수 있음: $e');
      }
    } catch (e) {
      debugPrint('❌ 서버 연결 테스트 오류: $e');
    }
  }

  static Future<void> testActualDataSending() async {
    try {
      final vin = await _secureStorage.read(key: 'currentVin');
      final accessToken = await _secureStorage.read(key: 'accessToken');
      if ((vin ?? '').isEmpty || (accessToken ?? '').isEmpty) return;
      final testLog = DrivingData(
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        totalDistance: 10, // 0.01km
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        destination: '테스트 목적지',
        destinationLat: 0.0,
        destinationLng: 0.0,
        reachedDestination: true,
      );
      final ok = await _sendSingleLogToServer(testLog, 0.01);
      debugPrint(ok ? '✅ 실제 데이터 전송 테스트 성공' : '❌ 실제 데이터 전송 테스트 실패');
    } catch (e) {
      debugPrint('❌ 실제 데이터 전송 테스트 오류: $e');
    }
  }
}

// 백그라운드 콜백
@pragma('vm:entry-point')
void callbackDispatcher() {
  // ✅ 중요: 백그라운드 isolate 초기화
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  Workmanager().executeTask((task, inputData) async {
    debugPrint('🌙 백그라운드 작업 실행: $task');
    try {
      switch (task) {
        case DailyLogBackupService.HOURLY_BACKUP_TASK:
          await DailyLogBackupService._performHourlyBackup();
          break;
        case DailyLogBackupService.WEEKLY_CLEANUP_TASK:
          await DailyLogBackupService._performWeeklyCleanup();
          break;
        case DailyLogBackupService.ONEOFF_WARMUP_TASK:
          await DailyLogBackupService._performHourlyBackup();
          break;
      }
      return Future.value(true);
    } catch (e, st) {
      debugPrint('❌ 백그라운드 작업 오류: $e\n$st');
      return Future.value(false);
    }
  });
}
