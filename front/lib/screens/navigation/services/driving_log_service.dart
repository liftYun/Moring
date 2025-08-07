import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/driving_data.dart';

class DrivingLogService {
  static const String _fileName = 'driving_logs.json';
  
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
  
  // 주행 로그 저장 (로컬)
  static Future<void> saveDrivingLog(DrivingData drivingData) async {
    try {
      final file = File(await _logFilePath);
      List<DrivingData> logs = await loadDrivingLogs();
      
      // 새로운 로그 추가
      logs.add(drivingData);
      
      // JSON으로 변환하여 저장
      final jsonList = logs.map((log) => log.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      
      print('✅ 주행 로그 저장 완료: ${drivingData.formattedDistance}');
    } catch (e) {
      print('❌ 주행 로그 저장 실패: $e');
    }
  }
  
  // 주행 로그 불러오기 (로컬)
  static Future<List<DrivingData>> loadDrivingLogs() async {
    try {
      final file = File(await _logFilePath);
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      
      return jsonList.map((json) => DrivingData.fromJson(json)).toList();
    } catch (e) {
      print('❌ 주행 로그 불러오기 실패: $e');
      return [];
    }
  }
  
  // 서버로 주행 로그 전송
  static Future<bool> sendDrivingLogToServer(DrivingData drivingData) async {
    try {
      // TODO: 실제 서버 API 호출 구현
      // final response = await http.post(
      //   Uri.parse('YOUR_API_ENDPOINT/driving-logs'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode(drivingData.toJson()),
      // );
      
      // 임시로 성공으로 처리
      await Future.delayed(Duration(milliseconds: 500));
      print('✅ 서버로 주행 로그 전송 완료');
      return true;
    } catch (e) {
      print('❌ 서버로 주행 로그 전송 실패: $e');
      return false;
    }
  }
  
  // 전송되지 않은 로그들 서버로 전송
  static Future<void> syncPendingLogs() async {
    try {
      final logs = await loadDrivingLogs();
      List<DrivingData> pendingLogs = [];
      
      for (var log in logs) {
        // TODO: 전송 상태 확인 로직 구현
        // if (!log.isSynced) {
        //   pendingLogs.add(log);
        // }
      }
      
      for (var log in pendingLogs) {
        final success = await sendDrivingLogToServer(log);
        if (success) {
          // TODO: 전송 완료 상태로 업데이트
          print('✅ 로그 동기화 완료: ${log.formattedDistance}');
        }
      }
    } catch (e) {
      print('❌ 로그 동기화 실패: $e');
    }
  }
  
  // 로그 파일 삭제
  static Future<void> clearLogs() async {
    try {
      final file = File(await _logFilePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ 주행 로그 삭제 완료');
      }
    } catch (e) {
      print('❌ 주행 로그 삭제 실패: $e');
    }
  }
}
