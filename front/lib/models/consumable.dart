import 'package:flutter/material.dart';

class Consumable {
  final Icon icon; // 앱 아이콘
  final String title; // 소모품 이름
  final DateTime lastReplacedDate; // 마지막 교체일
  final int replacementCycleMonths; // 교체 주기 (개월)

  Consumable({
    required this.icon,
    required this.title,
    required this.lastReplacedDate,
    required this.replacementCycleMonths,
  });

  // 교체 주기 대비 남은 퍼센티지 계산
  double getRemainingPercentage() {
    final now = DateTime.now();
    final int monthsPassed = (now.year - lastReplacedDate.year) * 12 +
        (now.month - lastReplacedDate.month);

    if (monthsPassed >= replacementCycleMonths) {
      return 0.0; // 교체 주기를 넘었으면 0%
    } else {
      return (replacementCycleMonths - monthsPassed) / replacementCycleMonths;
    }
  }

  // 다음 교체일 계산 (선택 사항)
  DateTime getNextReplacementDate() {
    return DateTime(
      lastReplacedDate.year + (lastReplacedDate.month + replacementCycleMonths - 1) ~/ 12,
      (lastReplacedDate.month + replacementCycleMonths - 1) % 12 + 1,
      lastReplacedDate.day,
    );
  }
}