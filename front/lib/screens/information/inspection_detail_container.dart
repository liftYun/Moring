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

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateOnly(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final i = s.indexOf('T');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _load() async {
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
      // ✅ paging 엔드포인트 사용 (Home에서도 이걸 쓰고 있음)
      final resp = await dio.get('/api/v1/cars/$vin/inspection-logs-paging?page=0&size=10');

      if (resp.statusCode == 200 && resp.data['isSuccess'] == true) {
        final List content = resp.data['result']['content'] ?? [];

        // ✅ 상세 페이지가 기대하는 키들로 정규화
        final mapped = content.map<Map<String, dynamic>>((e) {
          final dateRaw = e['inspectionDateTime'] ?? e['inspectionDatetime'];
          final status = e['inspectionStatus'];
          return {
            // 상세 페이지 where 필터: inspectionStatus 또는 status
            'inspectionStatus': status,
            'status': status,
            // 상세 페이지 날짜 추출 로직이 여러 케이스 지원하므로 모두 맞춰줌
            'inspectionDateTime': e['inspectionDateTime'],
            'inspectionDatetime': e['inspectionDatetime'],
            // 보조 키 (리스트 카드에서 바로 씀)
            'date': _dateOnly(dateRaw),
            // 원본도 detail로 전달
            'detail': e,
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          _logs = mapped;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = '점검 로그를 불러오지 못했습니다 (${resp.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '점검 로그 로딩 오류: $e';
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
    return InspectionDetailPage(inspectionLogs: _logs, vin: _vin!);
  }
}
