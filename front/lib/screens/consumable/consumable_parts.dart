import 'package:flutter/material.dart';
import 'package:moring/models/consumable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/screens/car_regist_ocr.dart'; // OCR import

class ConsumablePartsScreen extends ConsumerStatefulWidget {
  final List<Consumable> consumables;
  final String vin;

  const ConsumablePartsScreen({Key? key, required this.consumables, required this.vin}) : super(key: key);

  @override
  ConsumerState<ConsumablePartsScreen> createState() => _ConsumablePartsScreenState();
}

class _ConsumablePartsScreenState extends ConsumerState<ConsumablePartsScreen> {
  Consumable? _selectedConsumable;
  final _replacementDateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
      final selectedIndex = widget.consumables.indexOf(consumable);
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
              primary: Colors.blue,
              onPrimary: Colors.white,
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
        _replacementDateController.text =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _postChangeLog() async {
    if (_selectedConsumable == null) return;

    final data = {
      'vin': widget.vin,
      'partId': _selectedConsumable!.id,
      'changedAt': _replacementDateController.text + 'T00:00:00.000Z',
    };

    final dio = ref.read(authDioProvider);
    try {
      final response = await dio.post('/api/v1/parts/change-log', data: data);
      if (response.statusCode == 200) {
        // **등록 성공! → 최신 데이터로 재조회!**
        final statusResp = await dio.get('/api/v1/parts/status/${widget.vin}');
        if (statusResp.statusCode == 200 && statusResp.data['result'] != null) {
          // consumable 리스트 최신화
          final List list = statusResp.data['result'] as List;
          setState(() {
            // 화면 갱신!
            widget.consumables.clear();
            widget.consumables.addAll(list.map((e) => Consumable.fromJson(e)));
            _selectedConsumable = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('교체 이력이 등록되었습니다!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이력 등록 실패: $e')),
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
            '${consumable.title} 교체한 일자 변경',
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
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white, fontSize: 18)),
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

    final progress = consumable.remainingPercentage;

    return GestureDetector(
      onTap: () => _onConsumableTap(consumable),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
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
                      '$formattedDueDate',
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
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_weak, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CarOcrRegistrationPage()),
              );
            },
          ),
        ],
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
              ...widget.consumables.expand((consumable) {
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
            ],
          ),
        ),
      ),
    );
  }
}
