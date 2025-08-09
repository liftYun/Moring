// lib/screens/information/driving_record_container.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/screens/information/driving_record.dart';

class DrivingRecordContainerPage extends ConsumerStatefulWidget {
  const DrivingRecordContainerPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DrivingRecordContainerPage> createState() => _DrivingRecordContainerPageState();
}

class _DrivingRecordContainerPageState extends ConsumerState<DrivingRecordContainerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vin = ref.read(currentVinProvider);
      if (vin == null) {
        setState(() {
          _error = '차량 정보를 찾을 수 없습니다.';
          _loading = false;
        });
        return;
      }
      final dio = ref.read(authDioProvider);
      final resp = await dio.get(
          '/api/v1/cars/$vin/mileage-logs-paging?page=0&size=50');
      if (resp.statusCode == 200 && resp.data['isSuccess'] == true) {
        final List content = resp.data['result']['content'] ?? [];
        _logs = content.map<Map<String, dynamic>>((e) =>
        {
          'distance': '${e['mileageKm']} km',
          'date': e['recordedDate'] ?? '',
        }).toList();
        setState(() => _loading = false);
      } else {
        setState(() {
          _error = '주행 로그를 불러오지 못했습니다 (${resp.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '주행 로그 로딩 오류: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('주행 로그 전체 보기')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('주행 로그 전체 보기')),
        body: Center(child: Text(_error!)),
      );
    }

    // ✅ 기존 페이지 그대로 재사용
    return DrivingRecordPage(logs: _logs);
  }
}
