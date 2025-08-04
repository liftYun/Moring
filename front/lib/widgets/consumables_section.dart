// Path: front/lib/widgets/consumables_section.dart

import 'package:flutter/material.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/utils/app_icon.dart';
import 'package:moring/screens/consumable/consumable_parts.dart';

/// 소모품 리스트 섹션 (홈 화면용)
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
        SizedBox(
          height: 250, // 높이는 그대로 유지
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: consumables.length,
            itemBuilder: (context, index) {
              final consumable = consumables[index];
              final date = '${consumable.lastReplacedDate.year}-${consumable.lastReplacedDate.month.toString().padLeft(2, '0')}-${consumable.lastReplacedDate.day.toString().padLeft(2, '0')}';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConsumablePartsScreen(),
                    ),
                  );
                },
                child: _ConsumableCard(
                  icon: consumable.icon,
                  title: consumable.title,
                  date: date, // 'YYYY-MM-DD' 형식의 날짜만 전달
                  progress: consumable.getRemainingPercentage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// _ConsumableCard 위젯 (홈 화면용)
class _ConsumableCard extends StatelessWidget {
  final Icon icon;
  final String title;
  final String date; // 'YYYY-MM-DD' 형식의 다음 교체일
  final double progress; // 0.0 ~ 1.0

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
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // '다음 교체: YYYY-MM-DD' 형식의 날짜
                  Text(
                    '$date',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            // 프로그레스 바와 퍼센트를 가로로 배치
            Row(
              children: [
                SizedBox(
                  width: 80, // 프로그레스 바의 너비
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
                const SizedBox(width: 8), // 프로그레스 바와 퍼센트 사이 간격
                Text(
                  '${(progress * 100).toInt()}%', // 퍼센트 표시
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