import 'package:flutter/material.dart';
import 'package:moring/models/consumable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/screens/consumable/part_regist_ocr.dart';
import 'package:dio/dio.dart';
import 'package:moring/screens/consumable/part_change.dart';
import 'package:moring/screens/home_content.dart';

class ConsumablePartsScreen extends ConsumerStatefulWidget {
  final List<Consumable> consumables;
  final String vin;
  final List<int>? updatedPartIds;

  const ConsumablePartsScreen({
    Key? key,
    required this.consumables,
    required this.vin,
    this.updatedPartIds,
  }) : super(key: key);

  @override
  ConsumerState<ConsumablePartsScreen> createState() => _ConsumablePartsScreenState();
}

class _ConsumablePartsScreenState extends ConsumerState<ConsumablePartsScreen> {
  Consumable? _selectedConsumable;
  final _replacementDateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<int> _updatedPartIds = [];
  List<Consumable> _consumables = [];

  @override
  void initState() {
    super.initState();
    if (widget.updatedPartIds != null) {
      _updatedPartIds = List.from(widget.updatedPartIds!);
    }
    _consumables = List.from(widget.consumables);
  }

  @override
  void dispose() {
    _replacementDateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConsumableTap(Consumable consumable) {
    setState(() {
      if (_selectedConsumable == consumable) {
        _selectedConsumable = null;
      } else {
        _selectedConsumable = consumable;
        _replacementDateController.text =
        consumable.dueDate != null
            ? '${consumable.dueDate!.year}-${consumable.dueDate!.month.toString().padLeft(2, '0')}-${consumable.dueDate!.day.toString().padLeft(2, '0')}'
            : '';
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedIndex = _consumables.indexOf(consumable);
      if (selectedIndex != -1) {
        _scrollController.animateTo(
          (selectedIndex * 100.0) + 100,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
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
              onPrimary: Colors.white,
              surface: Color(0xFF232326),
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
        _replacementDateController.text =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _postChangeLog() async {
    if (_selectedConsumable == null) return;

    try {
      final parsedDate = DateTime.parse(_replacementDateController.text);
      final data = {
        'vin': widget.vin,
        'partIdList': [_selectedConsumable!.id],
        'changedAt': parsedDate.toIso8601String(),
      };

      final dio = ref.read(authDioProvider);
      final response = await dio.post('/api/v1/parts/change-log', data: data);

      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final statusResp = await dio.get('/api/v1/parts/status/${widget.vin}');
        if (statusResp.statusCode == 200 && statusResp.data['isSuccess'] == true) {
          final List list = statusResp.data['result'] as List;
          setState(() {
            _consumables = list.map((e) => Consumable.fromJson(e)).toList();
            _selectedConsumable = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('교체 이력이 등록되었습니다!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('교체 이력은 등록되었지만, 목록을 새로고침하는 데 실패했습니다.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이력 등록 실패: ${response.data['message'] ?? '알 수 없는 오류'}')),
        );
      }
    } catch (e) {
      String errorMessage = '이력 등록 중 오류가 발생했습니다: $e';
      if (e is DioException) {
        errorMessage = '이력 등록 실패: ${e.response?.data['message'] ?? e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Widget _buildConsumableInputForm(Consumable consumable) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            '교체 일자 변경',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _replacementDateController,
            readOnly: true,
            onTap: _showDatePicker,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _postChangeLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF50C878), // ✅ 색상 코드 변경
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildConsumableItemCard({
    required BuildContext context,
    required Consumable consumable,
  }) {
    final formattedDueDate = consumable.dueDate != null
        ? '${consumable.dueDate!.year}-${consumable.dueDate!.month.toString().padLeft(2, '0')}-${consumable.dueDate!.day.toString().padLeft(2, '0')}'
        : '날짜 정보 없음';

    final progress = consumable.dueDate != null ? consumable.remainingPercentage : 0.0;
    final isUpdated = _updatedPartIds.isNotEmpty && _updatedPartIds.contains(consumable.id);
    final hasDueDate = consumable.dueDate != null;

    // 디버깅 로그 추가
    print('[ _buildConsumableItemCard ] 부품 ID: ${consumable.id}, 제목: ${consumable.title}');
    print('[ _buildConsumableItemCard ] _updatedPartIds: $_updatedPartIds');
    print('[ _buildConsumableItemCard ] isUpdated: $isUpdated');

    return GestureDetector(
      onTap: () => _onConsumableTap(consumable),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isUpdated
              ? const BorderSide(color: Colors.greenAccent, width: 1.0)
              : BorderSide.none,
        ),
        color: isUpdated ? Colors.greenAccent.withOpacity(0.1) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isUpdated)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24)
              else
                consumable.icon,
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consumable.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDueDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 80,
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
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 35, // "100%"를 담을 수 있는 충분한 너비
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      textAlign: TextAlign.end, // ✅ 텍스트를 오른쪽 정렬
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소모품 상세'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '교체 날짜',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ..._consumables.expand((consumable) {
                List<Widget> widgets = [
                  _buildConsumableItemCard(
                    context: context,
                    consumable: consumable,
                  ),
                ];
                if (_selectedConsumable != null && _selectedConsumable == consumable) {
                  widgets.add(_buildConsumableInputForm(_selectedConsumable!));
                }
                return widgets;
              }).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  print('[내역 수정하기] 버튼 클릭됨');
                  final dynamic result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BulkPartRegistrationPage(vin: widget.vin),
                    ),
                  );
                  print('[내역 수정하기] Navigator.pop 결과: $result');

                  List<int>? updatedPartIds;

                  if (result != null) {
                    if (result is List<int>) {
                      updatedPartIds = result;
                      print('[내역 수정하기] List<int> 형태로 받음: $updatedPartIds');
                    } else if (result is Map<String, dynamic>) {
                      updatedPartIds = result['partIdList']?.cast<int>();
                      print('[내역 수정하기] Map에서 partIdList 추출: $updatedPartIds');
                    }

                    if (updatedPartIds != null && updatedPartIds.isNotEmpty) {
                      print('[내역 수정하기] 업데이트된 부품 IDs: $updatedPartIds');
                      // 서버에서 최신 데이터를 가져와서 화면 업데이트
                      try {
                        final dio = ref.read(authDioProvider);
                        final response = await dio.get('/api/v1/parts/status/${widget.vin}');
                        if (response.statusCode == 200 && response.data['isSuccess'] == true) {
                          final List list = response.data['result'] as List;
                          setState(() {
                            _consumables = list.map((e) => Consumable.fromJson(e)).toList();
                            _updatedPartIds = List<int>.from(updatedPartIds ?? []);
                          });
                          print('[내역 수정하기] setState 완료, _updatedPartIds: $_updatedPartIds');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('소모품 교체 이력이 업데이트되었습니다!')),
                          );
                        }
                      } catch (e) {
                        print('[내역 수정하기] 오류 발생: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('데이터 새로고침 실패: $e')),
                        );
                      }
                    } else {
                      print('[내역 수정하기] updatedPartIds가 null이거나 비어있음');
                    }
                  } else {
                    print('[내역 수정하기] result가 null');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50C878), // ✅ 색상 코드 변경
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('내역 수정하기', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
