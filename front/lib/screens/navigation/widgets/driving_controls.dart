import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:moring/screens/navigation/information/backup_settings.dart';
import 'package:moring/screens/navigation/services/daily_log_backup_service.dart';

class DrivingControls extends StatelessWidget {
  final bool hasAuto;              // 자동 측정 중인지 여부
  final bool isDriving;            // 운전 중인지 여부
  final VoidCallback onStartDriving;
  final VoidCallback onStopDriving;
  final String totalDistance;     // 자동 측정된 총 거리
  final String drivingTime;       // 표시할 시간
  final String remainingDistance; // 남은 거리
  final String timeLabel;         // 🆕 시간 라벨 ("자동측정" 또는 "경로시간")
  final String buttonText;        // 🆕 버튼 텍스트
  final bool hasDestination;      // 🆕 목적지 여부

  const DrivingControls({
    super.key,
    required this.hasAuto,
    required this.isDriving,
    required this.onStartDriving,
    required this.onStopDriving,
    required this.totalDistance,
    required this.drivingTime,
    required this.remainingDistance,
    required this.timeLabel,        // 🆕 필수 파라미터
    required this.buttonText,       // 🆕 필수 파라미터
    required this.hasDestination,   // 🆕 필수 파라미터
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final dynamicMargin = screenHeight * 0.02;
    final infoBarHeight = screenHeight * 0.07;
    final buttonHeight = screenHeight * 0.06;
    final iconSectionWidth = infoBarHeight;

    // 키보드가 올라왔는지 확인
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // 키보드가 올라왔으면 위젯을 숨김
    if (isKeyboardVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: dynamicMargin,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // 📊 자동 측정 정보바 - 안전 운전 중일 때만 표시
          if (isDriving) // 🆕 안전 운전 버튼을 눌렀을 때만 표시
            Container(
              width: double.infinity,
              height: infoBarHeight,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 🔄 백업 기능 아이콘
                  GestureDetector(
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BackupSettingsPage()),
                      );
                    },
                    onLongPress: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 백업 실행 중...'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 1),
                          ),
                        );
                        await DailyLogBackupService.runManualBackup();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ 백업 완료!'),
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
                      }
                    },
                    child: Container(
                      width: iconSectionWidth,
                      height: infoBarHeight,
                      decoration: BoxDecoration(
                        color: hasAuto ? Colors.green[100] : Colors.grey[100], // 자동 측정 상태에 따른 색상
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Icon(
                        hasAuto ? Icons.auto_mode : Icons.backup, // 자동 측정 상태에 따른 아이콘
                        color: hasAuto ? Colors.green[700] : Colors.grey[600],
                        size: infoBarHeight * 0.4,
                      ),
                    ),
                  ),

                  // 📈 주행 정보 (자동 측정 데이터 표시)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // ⏱️ 시간 (자동 측정 또는 경로 시간)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  drivingTime,
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.26,
                                    fontWeight: FontWeight.bold,
                                    color: hasDestination 
                                        ? Colors.blue[700]     // 🆕 목적지 있으면 파란색 (경로 시간)
                                        : (hasAuto ? Colors.green[700] : Colors.grey[600]), // 목적지 없으면 초록색 (자동 측정)
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  timeLabel, // 🆕 동적 라벨 ("자동측정" 또는 "경로시간")
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 📏 자동 측정 거리
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  totalDistance,
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.26,
                                    fontWeight: FontWeight.bold,
                                    color: hasAuto ? Colors.green[700] : Colors.grey[600], // 자동 측정 상태에 따른 색상
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '주행거리',
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🎯 남은 거리 (목적지가 있을 때만 표시)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  remainingDistance,
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.26,
                                    fontWeight: FontWeight.bold,
                                    color: remainingDistance != '-' ? Colors.blue[700] : Colors.grey[400], // 목적지 유무에 따른 색상
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '남은거리',
                                  style: TextStyle(
                                    fontSize: infoBarHeight * 0.16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 🚗 운전 시작/종료 버튼
          Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDriving ? onStopDriving : onStartDriving,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDriving
                          ? [
                        Colors.teal[700]!,  // 운전 종료 (진한 teal)
                        Colors.teal[900]!,
                      ]
                          : [
                        Colors.teal[400]!,  // 운전 시작 (밝은 teal)
                        Colors.teal[600]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDriving ? Icons.stop : (hasDestination ? Icons.navigation : Icons.directions_car),
                        color: Colors.white,
                        size: buttonHeight * 0.4,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText, // 🆕 동적 버튼 텍스트
                        style: TextStyle(
                          fontSize: buttonHeight * 0.32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}