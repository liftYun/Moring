import 'package:flutter/material.dart';

class DrivingRecordPage extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const DrivingRecordPage({Key? key, required this.logs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 로그 전체 보기'),
        backgroundColor: Colors.black,
      ),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, idx) {
          final log = logs[idx];
          return ListTile(
            leading: const Icon(Icons.place),
            title: Text('${log['distance']}'),
            subtitle: Text('${log['date']}'),
          );
        },
      ),
    );
  }
}
