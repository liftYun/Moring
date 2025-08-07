import 'package:flutter/material.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/screens/consumable/consumable_parts.dart';

class ConsumablesSection extends StatelessWidget {
  final List<Consumable> consumables;
  final String vin;

  const ConsumablesSection({
    super.key,
    required this.consumables,
    required this.vin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '소모품 현황',
          style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: consumables.length,
            itemBuilder: (context, index) {
              final consumable = consumables[index];
              final date = consumable.dueDate != null
                  ? '${consumable.dueDate!.year}-${consumable.dueDate!.month.toString().padLeft(2, '0')}-${consumable.dueDate!.day.toString().padLeft(2, '0')}'
                  : '날짜 정보 없음';

              // percentUsed: 0(새것) → 100(교체필요)
              final progress = 1.0 - (consumable.percentUsed / 100.0);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsumablePartsScreen(
                        consumables: consumables,
                        vin: vin,
                      ),
                    ),
                  );
                },
                child: _ConsumableCard(
                  icon: consumable.icon,
                  title: consumable.title,
                  date: date,
                  progress: progress,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConsumableCard extends StatelessWidget {
  final Icon icon;
  final String title;
  final String date;
  final double progress;

  const _ConsumableCard({
    required this.icon,
    required this.title,
    required this.date,
    required this.progress,
  });

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
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 80,
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
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
