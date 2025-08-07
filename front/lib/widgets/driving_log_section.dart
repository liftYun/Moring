import 'package:flutter/material.dart';

/// 주행 기록 섹션
class DrivingLogSection extends StatelessWidget {
  final String title;
  final List<Map<String, String>> logs;
  const DrivingLogSection({super.key, required this.title, required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: logs.map((log) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.location_on, color: Colors.white),
                title: Text(log['distance']!,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white)),
                subtitle: Text(log['time']!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey)),
                onTap: () {},
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
