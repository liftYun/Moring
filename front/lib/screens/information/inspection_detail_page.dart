import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/screens/car/registration_inspection.dart';

class InspectionDetailPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> inspectionLogs;
  final String vin;

  const InspectionDetailPage({
    Key? key,
    required this.inspectionLogs,
    required this.vin,
  }) : super(key: key);

  @override
  ConsumerState<InspectionDetailPage> createState() => _InspectionDetailPageState();
}

class _InspectionDetailPageState extends ConsumerState<InspectionDetailPage> {
  String? _pendingDate; // "2029-08-09" 형태

  @override
  void initState() {
    super.initState();
    _loadPendingDate();
  }

  Future<void> _loadPendingDate() async {
    try {
      final dio = ref.read(authDioProvider);
      final r = await dio.get('/api/v1/cars/${widget.vin}/latest-pending-inspection-date');
      if (r.statusCode == 200 && r.data is Map && r.data['result'] is String) {
        setState(() => _pendingDate = r.data['result'] as String);
      }
    } catch (_) {
      // 필요 시 스낵바 등 처리
    }
  }

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
    if (log['inspectionDateTime'] != null) return formatDate(log['inspectionDateTime']);
    if (log['inspectionDatetime'] != null) return formatDate(log['inspectionDatetime']);
    final d = log['detail'];
    if (d is Map && d['inspectionDateTime'] != null) return formatDate(d['inspectionDateTime']);
    if (d is Map && d['inspectionDatetime'] != null) return formatDate(d['inspectionDatetime']);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // '점검 완료' 상태만 필터링
    final completed = widget.inspectionLogs.where(
          (e) => (e['inspectionStatus'] == '점검 완료') || (e['status'] == '점검 완료'),
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('정기점검 내역'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다음 점검 일자',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (_pendingDate != null && _pendingDate!.isNotEmpty)
              Card(
                color: Color(0xFF232326),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                  title: Text(
                    _pendingDate!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('점검 대기',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              )
            else
              const Text('대기 중인 점검 없음', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            Text(
              '과거 이력',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: completed.map((e) {
                  return Card(
                    color: Color(0xFF232326),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.check_box,
                          color: Colors.lightBlueAccent, size: 28),
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InspectionRegistrationPage(),
            ),
          );
        },
        label: const Text('내역 추가하기'),
        icon: const Icon(Icons.add),
        backgroundColor: Color(0xFF232326),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
