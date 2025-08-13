import 'package:flutter/material.dart';
import 'package:moring/screens/navigation/services/daily_log_backup_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart'; // ✅ 추가: OneOff 트리거용

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  _BackupSettingsPageState createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool isBackingUp = false;
  bool isDebugging = false;
  String debugInfo = '';

  Future<void> _runManualBackup() async {
    setState(() {
      isBackingUp = true;
    });

    try {
      await DailyLogBackupService.runManualBackup();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 백업이 완료되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 백업 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isBackingUp = false;
      });
    }
  }

  Future<void> _checkBackupStatus() async {
    setState(() {
      isDebugging = true;
      debugInfo = '디버깅 중...';
    });

    try {
      List<String> debugLines = [];

      // 1. 로그 상태 확인
      debugLines.add('=== 로그 상태 확인 ===');
      final logStatus = await DailyLogBackupService.getLogStatus();
      debugPrint('📊 로그 상태: $logStatus');
      debugLines.add('총 로그 개수: ${logStatus['totalLogs']}');
      debugLines.add('총 주행거리: ${logStatus['totalDistanceKm']}km');

      if (logStatus['oldestLogDate'] != null) {
        debugLines.add('가장 오래된 로그: ${logStatus['oldestLogDate']}');
      }
      if (logStatus['newestLogDate'] != null) {
        debugLines.add('가장 최근 로그: ${logStatus['newestLogDate']}');
      }

      // 2. VIN과 토큰 확인
      debugLines.add('\n=== 인증 정보 확인 ===');
      const secureStorage = FlutterSecureStorage();
      final vin = await secureStorage.read(key: 'currentVin');
      final accessToken = await secureStorage.read(key: 'accessToken');

      debugPrint('🔑 VIN: $vin');
      debugPrint('🔑 토큰 존재: ${accessToken != null ? "있음" : "없음"}');

      debugLines.add('VIN: ${vin ?? "없음"}');
      debugLines.add('액세스 토큰: ${accessToken != null ? "있음 (${accessToken.length}자)" : "없음"}');

      // 3. 어제 로그 상세 확인
      debugLines.add('\n=== 어제 로그 확인 ===');
      final logs = await _loadDrivingLogsForDebug();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day);

      final yesterdayLogs = logs.where((log) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final logDate = DateTime(startTime.year, startTime.month, startTime.day);
          return logDate.isAtSameMomentAs(yesterdayDate);
        } catch (e) {
          return false;
        }
      }).toList();

      debugPrint('📋 어제 로그 개수: ${yesterdayLogs.length}');
      debugLines.add('어제(${yesterdayDate.month}/${yesterdayDate.day}) 로그: ${yesterdayLogs.length}개');

      if (yesterdayLogs.isNotEmpty) {
        final totalDistance = yesterdayLogs.fold<double>(
          0.0,
              (sum, log) => sum + ((log['totalDistance'] as num?)?.toDouble() ?? 0.0),
        ) /
            1000.0;
        debugPrint('📏 어제 총 거리: ${totalDistance.toStringAsFixed(2)}km');
        debugLines.add('어제 총 주행거리: ${totalDistance.toStringAsFixed(2)}km');

        for (int i = 0; i < yesterdayLogs.length; i++) {
          final log = yesterdayLogs[i];
          final distance = ((log['totalDistance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
          final startTime = log['startTime'] ?? '알 수 없음';
          debugLines.add('  로그 ${i + 1}: ${distance.toStringAsFixed(2)}km, $startTime');
        }
      } else {
        debugLines.add('어제 주행 로그가 없습니다.');
      }

      // 4. 오늘 로그도 확인
      debugLines.add('\n=== 오늘 로그 확인 ===');
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final todayLogs = logs.where((log) {
        try {
          final startTime = DateTime.parse(log['startTime']);
          final logDate = DateTime(startTime.year, startTime.month, startTime.day);
          return logDate.isAtSameMomentAs(todayDate);
        } catch (e) {
          return false;
        }
      }).toList();

      debugLines.add('오늘(${todayDate.month}/${todayDate.day}) 로그: ${todayLogs.length}개');

      if (todayLogs.isNotEmpty) {
        final todayDistance = todayLogs.fold<double>(
          0.0,
              (sum, log) => sum + ((log['totalDistance'] as num?)?.toDouble() ?? 0.0),
        ) /
            1000.0;
        debugLines.add('오늘 총 주행거리: ${todayDistance.toStringAsFixed(2)}km');
      }

      // 5. 날짜별 로그 요약
      if (logStatus['logsByDate'] != null) {
        final logsByDate = logStatus['logsByDate'] as Map<String, dynamic>;
        debugLines.add('\n=== 날짜별 로그 요약 ===');
        logsByDate.forEach((date, count) {
          debugLines.add('$date: ${count}개');
        });
      }

      setState(() {
        debugInfo = debugLines.join('\n');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 디버깅 완료! 아래 정보를 확인하세요'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ 디버깅 실패: $e');
      setState(() {
        debugInfo = '디버깅 실패: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 디버깅 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isDebugging = false;
      });
    }
  }

  // 로그 로드 함수 (디버깅용)
  Future<List<Map<String, dynamic>>> _loadDrivingLogsForDebug() async {
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

  Future<void> _testServerConnection() async {
    setState(() {
      isDebugging = true;
      debugInfo = '서버 연결 테스트 중...';
    });

    try {
      await DailyLogBackupService.testServerConnection();

      setState(() {
        debugInfo = '서버 연결 테스트 완료! 로그를 확인하세요.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 서버 연결 테스트 완료! (실제 데이터 전송 안됨)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        debugInfo = '서버 연결 테스트 실패: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 서버 연결 테스트 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isDebugging = false;
      });
    }
  }

  Future<void> _testActualDataSending() async {
    // 경고 다이얼로그 먼저 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF283038),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ 주의', style: TextStyle(color: Colors.white)),
        content: const Text(
          '이 테스트는 실제로 0.01km를 서버에 전송합니다.\n'
              '서버에 실제 데이터가 추가됩니다.\n\n'
              '정말 진행하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('진행'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isDebugging = true;
      debugInfo = '실제 데이터 전송 테스트 중...';
    });

    try {
      await DailyLogBackupService.testActualDataSending();

      setState(() {
        debugInfo = '실제 데이터 전송 테스트 완료! 로그를 확인하세요.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 실제 데이터 전송 완료! 0.01km가 서버에 추가되었습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        debugInfo = '실제 데이터 전송 테스트 실패: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 실제 데이터 전송 테스트 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isDebugging = false;
      });
    }
  }

  // ✅ 디버그: 백그라운드 워커 즉시 트리거 (네트워크 조건 없음)
  Future<void> _debugTriggerWorkNow() async {
    debugPrint('🧪 디버그: OneOff 즉시 트리거');
    await Workmanager().registerOneOffTask(
      'debug_now_${DateTime.now().millisecondsSinceEpoch}',
      DailyLogBackupService.ONEOFF_WARMUP_TASK,
      initialDelay: Duration.zero,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    // UI 피드백
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧪 워커 트리거 요청 보냄. 로그캣에서 콜백을 확인하세요.'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F26),
      appBar: AppBar(
        title: const Text('백업 설정'),
        backgroundColor: const Color(0xFF1A1F26),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF283038),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌙 자동 백업 (활성화)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매일 새벽 6시에 전날 주행 로그를 서버로 자동 백업합니다.',
                    style: TextStyle(
                      color: Colors.green[300],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '다음 백업: 내일 새벽 6:00',
                        style: TextStyle(
                          color: Colors.green[300],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: const Color(0xFF283038),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚀 수동 백업',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '어제 주행 로그를 수동으로 서버에 백업합니다.',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isBackingUp ? null : _runManualBackup,
                      icon: isBackingUp
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.backup),
                      label: Text(isBackingUp ? '백업 중...' : '지금 백업하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: const Color(0xFF283038),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔍 디버깅 도구',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '백업이 왜 안 되는지 원인을 찾아보세요.',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDebugging ? null : _checkBackupStatus,
                          icon: isDebugging
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.bug_report),
                          label: Text(isDebugging ? '확인 중...' : '상태 확인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDebugging ? null : _testServerConnection,
                          icon: isDebugging
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.wifi_tethering),
                          label: Text(isDebugging ? '테스트 중...' : '연결 테스트'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDebugging ? null : _testActualDataSending,
                          icon: isDebugging
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.warning),
                          label: Text(isDebugging ? '전송 중...' : '실제 데이터 전송'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ✅ 디버그: 워커 즉시 실행 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _debugTriggerWorkNow,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('백그라운드 워커 즉시 실행'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (debugInfo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF283038),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 디버깅 정보',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        debugInfo,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Card(
            color: const Color(0xFF283038),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 백업 정보',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('백업 대상', '어제 주행 로그만'),
                  _buildInfoRow('백업 방식', '자동 백업 + 수동 백업'),
                  _buildInfoRow('보관 기간', '로컬: 1주일, 서버: 영구 보관'),
                  _buildInfoRow('네트워크', 'Wi-Fi 또는 모바일 데이터'),
                  _buildInfoRow('테스트 주의', '빨간 버튼은 실제 데이터 전송함'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
