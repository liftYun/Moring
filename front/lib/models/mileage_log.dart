import 'package:flutter/material.dart';

class MileageLog {
  final int mileageKm;
  final DateTime recordedDate;

  MileageLog({
    required this.mileageKm,
    required this.recordedDate,
  });

  factory MileageLog.fromJson(Map<String, dynamic> json) {
    return MileageLog(
      mileageKm: json['mileageKm'] ?? 0,
      recordedDate: DateTime.parse(json['recordedDate']),
    );
  }
}
