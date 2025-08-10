import 'package:flutter/material.dart';

class DrivingRecordPage extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const DrivingRecordPage({Key? key, required this.logs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEmpty = logs.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 로그 전체 보기'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: isEmpty
          ? const Center(
        child: Text(
          '주행 기록이 없습니다.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, idx) {
          final log = logs[idx];
          return Card(
            color: const Color(0xFF232326),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.place, color: Colors.white54),
              title: Text(
                '${log['distance']}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${log['date']}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
