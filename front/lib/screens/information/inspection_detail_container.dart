// lib/screens/information/inspection_detail_container.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/screens/information/inspection_detail_page.dart';

class InspectionDetailContainerPage extends ConsumerStatefulWidget {
  const InspectionDetailContainerPage({super.key});

  @override
  ConsumerState<InspectionDetailContainerPage> createState() => _InspectionDetailContainerPageState();
}

class _InspectionDetailContainerPageState extends ConsumerState<InspectionDetailContainerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  String? _vin;
  String? _pendingDate;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String _dateOnly(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final i = s.indexOf('T');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _loadAllData() async {
    try {
      final vin = ref.read(currentVinProvider);
      if (vin == null) {
        if (!mounted) return;
        setState(() {
          _error = '차량 정보를 찾을 수 없습니다.';
          _loading = false;
        });
        return;
      }
      _vin = vin;

      final dio = ref.read(authDioProvider);

      // 1. 완료된 점검 기록 API 호출
      final logsResp = await dio.get('/api/v1/cars/$vin/inspection-logs-paging?page=0&size=10');
      // 2. 대기 중인 점검 날짜 API 호출
      final pendingResp = await dio.get('/api/v1/cars/$vin/latest-pending-inspection-date');

      if (logsResp.statusCode == 200 && logsResp.data['isSuccess'] == true &&
          pendingResp.statusCode == 200 && pendingResp.data['isSuccess'] == true) {

        final List content = logsResp.data['result']['content'] ?? [];
        final pendingDate = pendingResp.data['result'] as String?;

        final mapped = content.map<Map<String, dynamic>>((e) {
          final dateRaw = e['inspectionDateTime'] ?? e['inspectionDatetime'];
          final status = e['inspectionStatus'];
          return {
            'inspectionStatus': status,
            'status': status,
            'inspectionDateTime': e['inspectionDateTime'],
            'inspectionDatetime': e['inspectionDatetime'],
            'date': _dateOnly(dateRaw),
            'detail': e,
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          _pendingDate = pendingDate;
          _logs = mapped;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = '점검 정보를 불러오지 못했습니다.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '점검 정보 로딩 오류: $e';
        _loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('정기점검 내역')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('정기점검 내역')),
        body: Center(child: Text(_error!)),
      );
    }

    // ✅ 상세 페이지가 기대하는 형태로 보냄
    return InspectionDetailPage(
      inspectionLogs: _logs,
      pendingDate: _pendingDate,
      vin: _vin!,
      onRefresh: _loadAllData,
    );
  }
}
