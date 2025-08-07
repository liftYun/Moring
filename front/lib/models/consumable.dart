import 'package:flutter/material.dart';

class Consumable {
  final int id;
  final Icon icon;
  final String title;
  final DateTime? dueDate; // 다음 교체 예정일
  final int percentUsed;   // 0~100 (0: 새것, 100: 다씀)

  Consumable({
    required this.id,
    required this.icon,
    required this.title,
    this.dueDate,
    required this.percentUsed,
  });

  // 아이콘은 서버에 없으니 name_en 기준 임의 매핑
  static Icon iconFromName(String name) {
    switch (name.toLowerCase()) {
      case 'engine oil': return Icon(Icons.local_gas_station);
      case 'oil filter': return Icon(Icons.local_gas_station);
      case 'air filter': return Icon(Icons.air);
      case 'cabin filter': return Icon(Icons.air);
      case 'spark plug':
      case 'spark plugs': return Icon(Icons.auto_awesome);
      case 'brake fluid': return Icon(Icons.pause);
      case 'coolant': return Icon(Icons.device_thermostat);
      case 'transmission fluid': return Icon(Icons.radio);
      case 'tire': return Icon(Icons.adjust);
      case 'brake pad': return Icon(Icons.panorama_fish_eye);
      case 'wiper blade': return Icon(Icons.ac_unit);
      default: return Icon(Icons.help_outline);
    }
  }

  factory Consumable.fromJson(Map<String, dynamic> json) {
    return Consumable(
      id: json['partId'] ?? json['id'] ?? 0,
      icon: iconFromName(json['nameEn'] ?? json['name_en'] ?? ''),
      title: json['nameEn'] ?? json['name_en'] ?? '',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      percentUsed: json['percentUsed'] ?? 0,
    );
  }

  /// 서버에서 percentUsed(0~100)로 내려주므로 100 → 1.0, 0 → 0.0로 변환
  double get remainingPercentage => 1.0 - (percentUsed / 100.0);
}
