// Path: front/lib/models/consumable.dart

import 'package:flutter/material.dart';

class Consumable {
  final Icon icon;
  final String title;
  final DateTime lastReplacedDate; // 마지막 교체일
  final int replacementCycleMonths; // 교체 주기 (월 단위)

  Consumable({
    required this.icon,
    required this.title,
    required this.lastReplacedDate,
    required this.replacementCycleMonths,
  });

  // 다음 교체일 계산
  DateTime getNextReplacementDate() {
    return DateTime(
      lastReplacedDate.year,
      lastReplacedDate.month + replacementCycleMonths,
      lastReplacedDate.day,
    );
  }

  // 남은 퍼센트 계산
  double getRemainingPercentage() {
    final DateTime now = DateTime.now();
    final DateTime nextReplacementDate = getNextReplacementDate();

    // 전체 주기 길이 (밀리초)
    final int totalCycleMilliseconds = nextReplacementDate.difference(lastReplacedDate).inMilliseconds;

    // 현재까지 사용된 주기 길이 (밀리초)
    final int elapsedMilliseconds = now.difference(lastReplacedDate).inMilliseconds;

    if (totalCycleMilliseconds <= 0) {
      return 0.0; // 주기가 유효하지 않으면 0%
    }

    double progress = 1.0 - (elapsedMilliseconds / totalCycleMilliseconds);

    // 0% ~ 100% 범위로 제한
    return progress.clamp(0.0, 1.0);
  }
}