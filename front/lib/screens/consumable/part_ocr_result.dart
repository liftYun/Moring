import 'package:flutter/material.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart'; // authDioProvider

// 부품 ID → 부품명 매핑
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

// 부품 ID → 아이콘 매핑
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

class PartOcrResultPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> ocrResult;
  final String vin; // 차량 식별자

  const PartOcrResultPage({
    Key? key,
    required this.ocrResult,
    required this.vin,
  }) : super(key: key);

  @override
  ConsumerState<PartOcrResultPage> createState() => _PartOcrResultPageState();
}

class _PartOcrResultPageState extends ConsumerState<PartOcrResultPage> {
  late String _changedAt;
  late List<int> _partIdList;
  late final TextEditingController _changedAtController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final fullDate = widget.ocrResult['changedAt'] ?? '';
    _changedAt = fullDate.split('T')[0];
    _partIdList = List<int>.from(widget.ocrResult['partIdList'] ?? []);
    _changedAtController = TextEditingController(text: _changedAt);
  }

  @override
  void dispose() {
    _changedAtController.dispose();
    super.dispose();
  }

  Future<void> _postChangeLogs() async {
    if (_partIdList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 부품이 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(authDioProvider);
      final res = await dio.post(
        '/api/v1/parts/change-log',
        data: {
          "vin": widget.vin,
          "changedAt": _changedAtController.text,
          "partIdList": _partIdList,
        },
      );

      if (res.statusCode == 200 && res.data['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경 이력이 등록되었습니다.')),
        );
        // 성공 시 consumable_parts로 이동하면서 변경된 부품 IDs 전달
        Navigator.pop(context, _partIdList);
      } else {
        throw Exception(res.data['message'] ?? '등록 실패');
      }
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
      appBar: CustomAppBar(
        title: 'OCR 결과',
        onBackButtonPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 교체 날짜
            Text('교체 날짜', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _changedAtController,
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_changedAt) ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (BuildContext context, Widget? child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF50C878),
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
                    _changedAt = _changedAtController.text =
                        pickedDate.toIso8601String().substring(0, 10);
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // 부품 목록
            Text('교체된 부품', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ..._partIdList.map((partId) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    partIdToIcon[partId] ?? Icons.build,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: Text(
                    partIdToName[partId] ?? '알 수 없는 부품',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '교체일: ${_changedAtController.text}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon:
                    const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _partIdList.remove(partId);
                      });
                    },
                  ),
                ),
              );
            }),

            const Spacer(),

            // 일괄 등록 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  debugPrint("[PartOcrResultPage] 일괄 등록 클릭됨");
                  await _postChangeLogs();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
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
