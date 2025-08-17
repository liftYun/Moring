// lib/screens/information/driving_record.dart
import 'package:flutter/material.dart';
import 'package:moring/utils/base_scaffold.dart';

class DrivingRecordPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const DrivingRecordPage({Key? key, required this.logs}) : super(key: key);

  @override
  State<DrivingRecordPage> createState() => _DrivingRecordPageState();
}

class _DrivingRecordPageState extends State<DrivingRecordPage> {
  String? _selectedYear;
  String? _selectedMonth;
  List<String> _availableYears = [];
  final List<String> _allMonths = [
    '01', '02', '03', '04', '05', '06',
    '07', '08', '09', '10', '11', '12',
  ];
  List<Map<String, dynamic>> _filteredLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  void _initializeFilters() {
    // 현재 년도 기준으로 20년 전까지의 년도 목록 생성
    final currentYear = DateTime.now().year;
    final List<String> allYears = [];
    
    for (int year = currentYear; year >= currentYear - 20; year--) {
      allYears.add(year.toString());
    }
    
    if (widget.logs.isNotEmpty) {
      // 실제 로그 데이터에서 년도 추출
      final logYears = widget.logs
          .map((log) => log['date'].toString().substring(0, 4))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      
      // 실제 로그 데이터의 년도와 20년 범위의 년도를 합치고 중복 제거
      final combinedYears = {...allYears, ...logYears}.toList()
        ..sort((a, b) => b.compareTo(a));

      setState(() {
        _availableYears = combinedYears;
        // 기본 선택 값으로 '전체'를 설정하고, availableYears 리스트에 추가
        _selectedYear = '전체';
        _availableYears.insert(0, '전체');

        _selectedMonth = '전체';
      });
    } else {
      // 기록이 없을 경우에도 20년 범위의 년도와 '전체' 옵션 표시
      setState(() {
        _selectedYear = '전체';
        _availableYears = ['전체', ...allYears];
        _selectedMonth = '전체';
      });
    }
    _filterLogs();
  }

  void _filterLogs() {
    setState(() {
      _filteredLogs = widget.logs.where((log) {
        if (log['date'] == null || log['date'].isEmpty) return false;

        final year = log['date'].toString().substring(0, 4);
        final month = log['date'].toString().substring(5, 7);

        // '전체'가 선택된 경우 년도와 월 필터를 무시하도록 수정
        return (_selectedYear == '전체' || year == _selectedYear) &&
            (_selectedMonth == '전체' || month == _selectedMonth);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _filteredLogs.isEmpty;

    return BaseScaffold(
      title: '주행 로그 전체 보기',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // '전체' 옵션을 포함한 년도 선택 드롭다운
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: DropdownButton<String>(
                    value: _selectedYear,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    dropdownColor: const Color(0xFF232326),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedYear = newValue;
                        _filterLogs();
                      });
                    },
                    items: _availableYears.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value == '전체' ? '전체' : '$value년'),
                      );
                    }).toList(),
                  ),
                ),
                // 모든 월과 '전체' 옵션을 포함한 월 선택 드롭다운
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    dropdownColor: const Color(0xFF232326),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedMonth = newValue;
                        _filterLogs();
                      });
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: '전체',
                        child: Text('전체'),
                      ),
                      ..._allMonths.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text('$value월'),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isEmpty
                ? const Center(
              child: Text(
                '주행 기록이 없습니다.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
                : ListView.builder(
              itemCount: _filteredLogs.length,
              itemBuilder: (context, idx) {
                final log = _filteredLogs[idx];
                return Card(
                  color: const Color(0xFF232326),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.place, color: Colors.white54),
                    title: Text(
                      '${log['distance']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${log['date']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}