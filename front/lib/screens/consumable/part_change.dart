import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/screens/consumable/part_regist_ocr.dart';
import 'package:moring/screens/consumable/consumable_parts.dart';

const Map<int, String> partIdToName = {
  1: '에어필터',
  2: '엔진오일',
  3: '브레이크오일',
  4: '냉각수',
  5: '타이어',
  6: '브레이크패드',
  7: '와이퍼블레이드',
  8: '스파크플러그'
};

const Map<int, IconData> partIdToIcon = {
  1: Icons.air,
  2: Icons.local_gas_station,
  3: Icons.pause,
  4: Icons.device_thermostat,
  5: Icons.adjust,
  6: Icons.panorama_fish_eye,
  7: Icons.ac_unit,
  8: Icons.auto_awesome,
};

class BulkPartRegistrationPage extends ConsumerStatefulWidget {
  final String vin;
  final Map<String, dynamic>? ocrResult;

  const BulkPartRegistrationPage({
    Key? key,
    required this.vin,
    this.ocrResult,
  }) : super(key: key);

  @override
  ConsumerState<BulkPartRegistrationPage> createState() => _BulkPartRegistrationPageState();
}

class _BulkPartRegistrationPageState extends ConsumerState<BulkPartRegistrationPage> {
  final _replacementDateController = TextEditingController();
  List<Consumable> _consumables = [];
  List<int> _selectedPartIds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _replacementDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (widget.ocrResult != null) {
      final partIdList = widget.ocrResult!['partIdList'];
      if (partIdList is List && partIdList.isNotEmpty) {
        _selectedPartIds = List<int>.from(partIdList);
      }
      final changedAt = widget.ocrResult!['changedAt'];
      if (changedAt is String && changedAt.isNotEmpty) {
        try {
          final parsedDate = DateTime.parse(changedAt);
          _replacementDateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);
        } catch (_) {
          _replacementDateController.text = changedAt;
        }
      }
    }
    _fetchConsumables();
  }

  @override
  void dispose() {
    _replacementDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchConsumables() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(authDioProvider);
      final response = await dio.get('/api/v1/parts/status/${widget.vin}');
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final List list = response.data['result'] as List;
        setState(() {
          _consumables = list.map((e) => Consumable.fromJson(e)).toList();
        });
      } else {
        setState(() {
          _error = '소모품 목록을 불러오지 못했습니다.';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _error = '데이터 로딩 중 오류가 발생했습니다: ${e.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onCheckboxChanged(bool? isChecked, int partId) {
    setState(() {
      if (isChecked == true) {
        _selectedPartIds.add(partId);
      } else {
        _selectedPartIds.remove(partId);
      }
    });
  }

  Future<void> _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF50C878), // ✅ 색상 코드 변경
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _replacementDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _submitBulkChangeLog() async {
    if (_selectedPartIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교체할 소모품을 하나 이상 선택해주세요.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final parsedDate = DateTime.parse(_replacementDateController.text);
      final data = {
        'vin': widget.vin,
        'partIdList': _selectedPartIds,
        'changedAt': parsedDate.toIso8601String(),
      };
      final dio = ref.read(authDioProvider);
      final response = await dio.post('/api/v1/parts/change-log', data: data);
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 소모품들의 교체 이력이 일괄 등록되었습니다!')),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response.data['message'] ?? '등록 실패');
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: ${e.response?.data['message'] ?? e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교체 날짜 변경'),
        leading: BackButton(
            onPressed: () {
              Navigator.pop(context);
            }
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_weak, color: Colors.white),
            onPressed: () async {
              final List<int>? updatedPartIds = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PartOcrRegistrationPage(vin: widget.vin),
                ),
              );
              if (updatedPartIds != null && updatedPartIds.isNotEmpty) {
                final dio = ref.read(authDioProvider);
                try {
                  final statusResp = await dio.get('/api/v1/parts/status/${widget.vin}');
                  if (statusResp.statusCode == 200 && statusResp.data['result'] != null) {
                    final List list = statusResp.data['result'] as List;
                    setState(() {
                      _consumables = list.map((e) => Consumable.fromJson(e)).toList();
                      _selectedPartIds = List.from(updatedPartIds);
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('소모품 목록 새로고침 실패: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('교체 날짜',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF232326),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _replacementDateController,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white, fontSize: 20.0),
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: _showDatePicker,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.grey),
                        onPressed: _showDatePicker,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('교체할 부품 선택',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : Expanded(
              child: ListView.builder(
                itemCount: _consumables.length,
                itemBuilder: (context, index) {
                  final consumable = _consumables[index];
                  final isSelected = _selectedPartIds.contains(consumable.id);
                  return GestureDetector(
                    onTap: () {
                      _onCheckboxChanged(!isSelected, consumable.id);
                    },
                    child: Container(
                      height: 72,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF50C878).withOpacity(0.2) // ✅ 색상 코드 변경
                            : const Color(0xFF232326),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  partIdToIcon[consumable.id] ?? Icons.build,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      partIdToName[consumable.id] ?? consumable.title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '잔여량: ${(consumable.remainingPercentage * 100).toInt()}%',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                _onCheckboxChanged(value, consumable.id);
                              },
                              checkColor: Colors.black,
                              activeColor: const Color(0xFF50C878), // ✅ 색상 코드 변경
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitBulkChangeLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50C878), // ✅ 색상 코드 변경
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                  '일괄 등록',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}