import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/screens/car/registration_inspection.dart';
import 'package:moring/utils/base_scaffold.dart';

class InspectionDetailPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> inspectionLogs;
  final String vin;
  final String? pendingDate;
  final VoidCallback onRefresh;

  const InspectionDetailPage({
    Key? key,
    required this.inspectionLogs,
    required this.vin,
    required this.onRefresh,
    this.pendingDate,
  }) : super(key: key);

  @override
  ConsumerState<InspectionDetailPage> createState() => _InspectionDetailPageState();
}

class _InspectionDetailPageState extends ConsumerState<InspectionDetailPage> {
  // "2025-08-07T11:20:58.597802" → "2025-08-07"
  String formatDate(dynamic isoString) {
    if (isoString == null) return '';
    final s = isoString.toString();
    final i = s.indexOf('T');
    return i > 0 ? s.substring(0, i) : s;
  }

  // 완료 이력용 날짜 추출
  String extractDate(Map log) {
    if (log['date'] != null) return log['date'].toString();
    if (log['inspectionDatetime'] != null) return formatDate(log['inspectionDatetime']);
    if (log['inspectionDateTime'] != null) return formatDate(log['inspectionDateTime']);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final _completedLogs =
    widget.inspectionLogs.where((e) => (e['status'] == '점검 완료')).toList();

    return BaseScaffold(
      title: '정기점검 내역',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 다음 점검 일자 섹션
              Text(
                '다음 점검 일자',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.pendingDate != null && widget.pendingDate!.isNotEmpty)
                Card(
                  color: const Color(0xFF232326),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                    title: Text(
                      widget.pendingDate!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('점검 대기',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('대기 중인 점검 없음', style: TextStyle(color: Colors.grey)),
                ),
              const SizedBox(height: 24),

              // 과거 이력 섹션
              Text(
                '과거 이력',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              if (_completedLogs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('완료된 점검 이력 없음', style: TextStyle(color: Colors.grey)),
                )
              else
                Column(
                  children: _completedLogs.map((e) {
                    return Card(
                      color: const Color(0xFF232326),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const Icon(Icons.check_box,
                            color: Colors.greenAccent, size: 28),
                        title: Text(
                          extractDate(e),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          e['inspectionStatus'] ?? e['status'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // ✅ '내역 추가하기' 버튼 추가
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final isRegistered = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InspectionRegistrationPage(vin: widget.vin),
                      ),
                    );
                    if (isRegistered == true) {
                      // 새로고침 실행
                      widget.onRefresh();
                      // 성공 메시지 표시
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('점검 내역이 새로고침되었습니다.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('내역 추가하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50C878),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}