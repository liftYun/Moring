import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/driving_data.dart';
import 'driving_distance_service.dart';

/// 주행 로그 서비스 프로바이더
final drivingLogServiceProvider = Provider<DrivingLogService>((ref) {
  final drivingDistanceService = ref.read(drivingDistanceServiceProvider);
  return DrivingLogService(drivingDistanceService);
});

class DrivingLogService {
  static const String _fileName = 'driving_logs.json';
  final DrivingDistanceService _drivingDistanceService;

  DrivingLogService(this._drivingDistanceService);

  // 로컬 파일 경로 가져오기
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // 로그 파일 경로
  static Future<String> get _logFilePath async {
    final path = await _localPath;
    return '$path/$_fileName';
  }

  // 🆕 주행 로그 저장 (4시간 주기 전송을 위한 상태 포함)
  Future<void> saveDrivingLog(DrivingData drivingData) async {
    debugPrint('🚀 주행 로그 저장 시작...');

    try {
      // 디렉토리 존재 확인
      final directory = await getApplicationDocumentsDirectory();
      // debugPrint('📁 Documents 디렉토리: ${directory.path}');
      // debugPrint('📄 디렉토리 존재 여부: ${await directory.exists()}');

      // 파일 경로 확인
      final file = File(await _logFilePath);
      // debugPrint('📄 파일 경로: ${file.path}');

      // 기존 로그 로드 시도
      // debugPrint('📖 기존 로그 로드 중...');
      List<DrivingData> logs = await loadDrivingLogs();
      // debugPrint('📊 기존 로그 개수: ${logs.length}');

      // 🆕 새 로그 추가 (기본적으로 미전송 상태)
      final newLog = drivingData.copyWith(
        isSentToServer: false,
        retryCount: 0,
      );
      logs.add(newLog);
      // debugPrint('📈 새 로그 추가 후 개수: ${logs.length}');

      // JSON 변환 시도
      // debugPrint('🔄 JSON 변환 중...');
      final jsonList = logs.map((log) => log.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      // debugPrint('📏 JSON 문자열 길이: ${jsonString.length}');

      // 파일 쓰기 시도
      // debugPrint('💾 파일 쓰기 중...');
      await file.writeAsString(jsonString);

      // 쓰기 확인
      final exists = await file.exists();
      debugPrint('✅ 파일 쓰기 완료, 존재 여부: $exists');

      if (exists) {
        final size = await file.length();
        // debugPrint('📊 파일 크기: $size bytes');
      }

    } catch (e, stackTrace) {
      debugPrint('❌ 주행 로그 저장 실패: $e');
      debugPrint('📍 스택 트레이스: $stackTrace');
    }
  }

  // 주행 로그 불러오기 (로컬)
  static Future<List<DrivingData>> loadDrivingLogs() async {
    try {
      final file = File(await _logFilePath);
      // debugPrint('📄 로드할 파일 경로: ${file.path}');
      // debugPrint('📄 파일 존재 여부: ${await file.exists()}');

      if (!await file.exists()) {
        // debugPrint('📄 파일이 없어서 빈 리스트 반환');
        return [];
      }

      final jsonString = await file.readAsString();
      // debugPrint('📏 읽은 JSON 길이: ${jsonString.length}');
      // debugPrint('📄 JSON 내용 일부: ${jsonString.substring(0, math.min(100, jsonString.length))}');

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => DrivingData.fromJson(json)).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ 주행 로그 불러오기 실패: $e');
      debugPrint('📍 스택 트레이스: $stackTrace');
      return [];
    }
  }

  //  로그 리스트 저장 (상태 업데이트용)
  static Future<void> saveDrivingLogsList(List<DrivingData> logs) async {
    try {
      final file = File(await _logFilePath);
      final jsonList = logs.map((log) => log.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await file.writeAsString(jsonString);
      // debugPrint('✅ 로그 리스트 저장 완료: ${logs.length}개');
    } catch (e, stackTrace) {
      debugPrint('❌ 로그 리스트 저장 실패: $e');
      debugPrint('📍 스택 트레이스: $stackTrace');
    }
  }

  //  전송되지 않은 로그들 조회
  static Future<List<DrivingData>> getUnsentLogs() async {
    try {
      final allLogs = await loadDrivingLogs();
      final unsentLogs = allLogs.where((log) => !log.isSentToServer).toList();
      debugPrint('📤 전송되지 않은 로그: ${unsentLogs.length}개 / 전체 ${allLogs.length}개');
      return unsentLogs;
    } catch (e) {
      debugPrint('❌ 미전송 로그 조회 실패: $e');
      return [];
    }
  }

  //  특정 로그의 전송 상태 업데이트
  static Future<void> updateLogSentStatus(DrivingData originalLog, bool isSent, {int? newRetryCount}) async {
    try {
      final allLogs = await loadDrivingLogs();

      // 해당 로그 찾기 (시작 시간으로 식별)
      final index = allLogs.indexWhere((log) =>
          log.startTime.isAtSameMomentAs(originalLog.startTime));

      if (index != -1) {
        // 상태 업데이트
        allLogs[index] = allLogs[index].copyWith(
          isSentToServer: isSent,
          lastSentAttempt: DateTime.now(),
          retryCount: newRetryCount ?? allLogs[index].retryCount,
        );

        // 파일에 저장
        await saveDrivingLogsList(allLogs);
        // debugPrint('✅ 로그 전송 상태 업데이트: ${isSent ? "성공" : "실패"} (재시도: ${newRetryCount ?? allLogs[index].retryCount})');
      } else {
        debugPrint('❌ 업데이트할 로그를 찾을 수 없음');
      }
    } catch (e) {
      debugPrint('❌ 로그 상태 업데이트 실패: $e');
    }
  }

  // 로그 파일 삭제
  static Future<void> clearLogs() async {
    try {
      final file = File(await _logFilePath);
      if (await file.exists()) {
        await file.delete();
        // debugPrint('✅ 주행 로그 삭제 완료');
      }
    } catch (e) {
      debugPrint('❌ 주행 로그 삭제 실패: $e');
    }
  }

  /// 로컬 저장소 경로 정보 반환 및 디버그 출력
  static Future<String> getStorageInfo() async {
    final localPath = await _localPath;
    final logFilePath = await _logFilePath;

    final storageInfo = '''
📁 주행 로그 저장 위치:
- 디렉토리: $localPath
- 파일명: $_fileName
- 전체 경로: $logFilePath
''';

    // 디버그 출력도 함께
    // debugPrint('📁 주행 로그 저장 경로: $logFilePath');

    return storageInfo;
  }

  /// 저장 경로를 디버그 콘솔에 출력
  static Future<void> printStoragePath() async {
    final path = await _logFilePath;
    // debugPrint('📁 실제 주행 로그 저장 위치: $path');

    // 파일 존재 여부도 확인
    final file = File(path);
    final exists = await file.exists();
    // debugPrint('📄 파일 존재 여부: $exists');

    if (exists) {
      final stat = await file.stat();
      // debugPrint('📊 파일 크기: ${stat.size} bytes');
      // debugPrint('📅 마지막 수정: ${stat.modified}');
    }
  }

  //  전송 통계 조회 (디버깅용)
  static Future<Map<String, dynamic>> getTransmissionStats() async {
    try {
      final allLogs = await loadDrivingLogs();

      final totalLogs = allLogs.length;
      final sentLogs = allLogs.where((log) => log.isSentToServer).length;
      final unsentLogs = allLogs.where((log) => !log.isSentToServer).length;
      final retryingLogs = allLogs.where((log) => log.retryCount > 0).length;

      final stats = {
        'totalLogs': totalLogs,
        'sentLogs': sentLogs,
        'unsentLogs': unsentLogs,
        'retryingLogs': retryingLogs,
        'sendRate': totalLogs > 0 ? (sentLogs / totalLogs * 100).toStringAsFixed(1) : '0.0',
      };

      // debugPrint('📊 전송 통계: $stats');
      return stats;

    } catch (e) {
      debugPrint('❌ 전송 통계 조회 실패: $e');
      return {'error': e.toString()};
    }
  }
}