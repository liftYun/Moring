import 'package:flutter/material.dart';
import 'package:moring/models/consumable.dart';

/// 소모품 리스트 섹션
class ConsumablesSection extends StatelessWidget {
  final List<Consumable> consumables;
  const ConsumablesSection({Key? key, required this.consumables}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '소모품 현황',
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...consumables.map((c) {
          final next = c.getNextReplacementDate();
          final date = '${next.year}-${next.month.toString().padLeft(2,'0')}-${next.day.toString().padLeft(2,'0')}';
          return _ConsumableCard(
            icon: c.icon,
            title: c.title,
            date: date,
            progress: c.getRemainingPercentage(),
          );
        }).toList(),
      ],
    );
  }
}

class _ConsumableCard extends StatelessWidget {
  final Icon icon;
  final String title, date;
  final double progress;
  const _ConsumableCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.date,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('다음 교체: $date',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.7
                      ? Colors.greenAccent
                      : (progress > 0.3 ? Colors.amberAccent : Colors.redAccent),
                ),
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}