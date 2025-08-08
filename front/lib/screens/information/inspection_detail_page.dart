import 'package:flutter/material.dart';

class InspectionDetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> inspectionLogs;
  final int currentIndex;

  const InspectionDetailPage({
    Key? key,
    required this.inspectionLogs,
    this.currentIndex = 0,
  }) : super(key: key);

  // "2025-08-07T11:20:58.597802" → "2025-08-07"
  String formatDate(dynamic isoString) {
    if (isoString == null) return '';
    final str = isoString.toString();
    final idx = str.indexOf('T');
    if (idx > 0) {
      return str.substring(0, idx);
    }
    return str;
  }

  // inspectionLog 객체에서 날짜 추출 (모든 경우 지원)
  String extractDate(Map log) {
    // 1. 최상위에 date
    if (log['date'] != null) return log['date'];
    // 2. inspectionDateTime or inspectionDatetime
    if (log['inspectionDateTime'] != null) return formatDate(log['inspectionDateTime']);
    if (log['inspectionDatetime'] != null) return formatDate(log['inspectionDatetime']);
    // 3. detail 필드에 date
    if (log['detail'] != null && log['detail']['inspectionDateTime'] != null)
      return formatDate(log['detail']['inspectionDateTime']);
    if (log['detail'] != null && log['detail']['inspectionDatetime'] != null)
      return formatDate(log['detail']['inspectionDatetime']);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    print('inspectionLogs: $inspectionLogs');

    // 점검 대기 한 건만!
    final waiting = inspectionLogs.firstWhere(
          (e) => (e['inspectionStatus'] == '점검 대기') || (e['status'] == '점검 대기'),
      orElse: () => {},
    );
    final hasWaiting = waiting.isNotEmpty;

    // 점검 완료만 리스트업
    final completed = inspectionLogs.where(
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
                fontSize: 21,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (hasWaiting)
              Card(
                color: Colors.blueGrey[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                  title: Text(
                    extractDate(waiting),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    waiting['inspectionStatus'] ?? waiting['status'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              '과거 이력',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 21,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...completed.map((e) => Card(
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.check_box, color: Colors.lightBlueAccent, size: 28),
                title: Text(
                  extractDate(e),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  e['inspectionStatus'] ?? e['status'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
