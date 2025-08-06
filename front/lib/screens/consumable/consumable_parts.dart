// Path: front/lib/screens/consumable/consumable_parts.dart

import 'package:flutter/material.dart';
import 'package:moring/utils/app_icon.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/models/consumable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod import 추가
import 'package:moring/providers/api_client.dart'; // authDio import 추가

class ConsumablePartsScreen extends ConsumerStatefulWidget { // ConsumerStatefulWidget으로 변경
  final List<Consumable> consumables;

  const ConsumablePartsScreen({super.key, required this.consumables});

  @override
  ConsumerState<ConsumablePartsScreen> createState() => _ConsumablePartsScreenState(); // ConsumerState로 변경
}

class _ConsumablePartsScreenState extends ConsumerState<ConsumablePartsScreen> { // ConsumerState로 변경
  int _selectedIndex = 0;
  late List<Consumable> _consumables;
  Consumable? _selectedConsumable;
  final ScrollController _scrollController = ScrollController();

  final _replacementDateController = TextEditingController();
  final _replacementCycleMonthsController = TextEditingController();
  final _replacementCycleKmController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedType;

  // Dio 인스턴스 생성 로직을 제거합니다.
  // 대신 _updateConsumableData 함수에서 ref.read(authDioProvider)를 사용합니다.

  @override
  void initState() {
    super.initState();
    _consumables = widget.consumables;
  }

  @override
  void dispose() {
    _replacementDateController.dispose();
    _replacementCycleMonthsController.dispose();
    _replacementCycleKmController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConsumableTap(Consumable consumable) {
    if (_selectedConsumable == consumable) {
      setState(() {
        _selectedConsumable = null;
      });
    } else {
      setState(() {
        _selectedConsumable = consumable;
        _replacementDateController.text =
        '${consumable.lastReplacedDate.year}-${consumable.lastReplacedDate.month.toString().padLeft(2, '0')}-${consumable.lastReplacedDate.day.toString().padLeft(2, '0')}';
        _replacementCycleMonthsController.text =
        '${consumable.replacementCycleMonths}';
        _replacementCycleKmController.text = '10000';
        _notesController.text = '';
        _selectedType = 'CONSUMABLE';
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
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        debugPrint('ConsumablePartsScreen이 스택의 최상단입니다.');
      }
    }
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

  Future<void> _updateConsumableData() async {
    if (_selectedConsumable == null) return;

    final data = {
      'nameKo': _selectedConsumable!.title,
      'nameEn': _selectedConsumable!.title.replaceAll(' ', ''),
      'recommendedCycleMonths': int.tryParse(_replacementCycleMonthsController.text),
      'recommendedCycleKm': int.tryParse(_replacementCycleKmController.text),
      'type': _selectedType,
      'description': _notesController.text,
    };

    try {
      final dio = ref.read(authDioProvider); // ref를 사용해 authDio를 가져옵니다.
      final response = await dio.post('/api/v1/parts', data: data); // dio 인스턴스 사용
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('소모품 정보가 성공적으로 등록/수정되었습니다.')),
          );
        }
        setState(() {
          _selectedConsumable = null;
        });
      }
    } on DioException catch (e) {
      debugPrint('요청 실패: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('소모품 정보 등록/수정 실패: ${e.message}')),
        );
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            absorbing: onTap != null,
            child: TextField(
              controller: controller,
              readOnly: readOnly || onTap != null,
              keyboardType: keyboardType,
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
          ),
        ),
      ],
    );
  }

  Widget _buildConsumableInputForm(Consumable consumable) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            '${consumable.title} 상세 정보',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: '교체일',
            controller: _replacementDateController,
            readOnly: true,
            onTap: _showDatePicker,
          ),
          const SizedBox(height: 16),
          _buildTextField(label: '교체 주기(개월)', controller: _replacementCycleMonthsController),
          const SizedBox(height: 16),
          _buildTextField(label: '교체 주기(km)', controller: _replacementCycleKmController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('부품 유형', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: <String>['CONSUMABLE', 'EQUIPMENT', 'OTHER']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(label: '특이사항', controller: _notesController),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _updateConsumableData,
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
    final formattedLastReplacedDate = '${consumable.lastReplacedDate.year}-${consumable.lastReplacedDate.month.toString().padLeft(2, '0')}-${consumable.lastReplacedDate.day.toString().padLeft(2, '0')}';
    final progress = consumable.getRemainingPercentage();

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
                      '교체일: $formattedLastReplacedDate',
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
                        progress > 0.7 ? Colors.greenAccent : (progress > 0.3 ? Colors.amberAccent : Colors.redAccent),
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
      appBar: CustomAppBar(
        title: '소모품',
        onBackButtonPressed: () {
          Navigator.pop(context);
        },
        // onNotificationPressed: () {
        //   debugPrint('소모품 화면 알림 버튼 클릭!');
        // },
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
                    Row(
                      children: [
                        Text(
                          '교체 날짜',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort, color: Colors.white),
                      onPressed: () {
                        debugPrint('정렬/필터 버튼 클릭!');
                      },
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}