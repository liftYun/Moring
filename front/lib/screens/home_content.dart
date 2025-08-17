import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/screens/car/car_info.dart';
import 'package:moring/screens/information/driving_record.dart';
import 'package:moring/screens/information/inspection_detail_page.dart';
import 'package:moring/widgets/car_viewer_section.dart';
import 'package:moring/widgets/consumables_section.dart';

import '../providers/current_car_provider.dart';

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  List<Consumable> _consumables = [];
  bool _isLoading = true;
  String? _error;
  String? _carVin;
  List<String> _currentCarImagePaths = [];

  // 주행로그
  List<Map<String, dynamic>> _mileageLogs = [];
  bool _mileageLoading = true;
  String? _mileageError;

  // 점검로그
  List<Map<String, dynamic>> _inspectionLogs = [];
  bool _inspectionLoading = true;
  String? _inspectionError;
  String? _pendingDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final car = ref.read(currentCarProvider);
      if (car != null) {
        _carVin = car.vin;
        _setCarImages(car.modelName.toLowerCase());
        _fetchConsumables();
        _fetchMileageLogs();
        _fetchInspectionLogs();
      }
    });
  }

  Future<void> _fetchConsumables() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(authDioProvider);
      final response =
      await dio.get('/api/v1/parts/status/${_carVin ?? "TEST_VIN"}');
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final List list = response.data['result'] as List;
        setState(() {
          _consumables =
              list.map((e) => Consumable.fromJson(e)).toList();
        });
      } else {
        _error = '소모품을 불러오지 못했습니다: ${response.statusCode}';
      }
    } catch (e) {
      _error = '소모품을 가져오는 중 오류가 발생했습니다: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMileageLogs() async {
    setState(() {
      _mileageLoading = true;
      _mileageError = null;
    });
    try {
      final dio = ref.read(authDioProvider);
      final response = await dio.get(
          '/api/v1/cars/${_carVin ?? "TEST_VIN"}/mileage-logs-paging?page=0&size=10');
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final List content = response.data['result']['content'] ?? [];
        _mileageLogs = content
            .map((e) => {
          'distance': '${e['mileageKm']} km',
          'date': e['recordedDate'] ?? '',
        })
            .toList();
      } else {
        _mileageError =
        '주행로그를 불러오지 못했습니다: ${response.statusCode}';
      }
    } catch (e) {
      _mileageError = '주행로그를 가져오는 중 오류가 발생했습니다: $e';
    } finally {
      setState(() {
        _mileageLoading = false;
      });
    }
  }

  String _dateOnly(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final i = s.indexOf('T');
    return i > 0 ? s.substring(0, i) : s;
  }

  Future<void> _fetchInspectionLogs() async {
    setState(() {
      _inspectionLoading = true;
      _inspectionError = null;
    });
    try {
      final dio = ref.read(authDioProvider);
      
      // 1. 완료된 점검 기록 API 호출
      final logsResponse = await dio.get(
        '/api/v1/cars/${_carVin ?? "TEST_VIN"}/inspection-logs-paging?page=0&size=10',
      );
      
      // 2. 대기 중인 점검 날짜 API 호출
      final pendingResponse = await dio.get(
        '/api/v1/cars/${_carVin ?? "TEST_VIN"}/latest-pending-inspection-date',
      );
      
      if (logsResponse.statusCode == 200 && logsResponse.data['isSuccess'] == true) {
        final List content = logsResponse.data['result']['content'] ?? [];
        final pendingDate = pendingResponse.statusCode == 200 && pendingResponse.data['isSuccess'] == true 
            ? pendingResponse.data['result'] as String? 
            : null;
        
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
          _inspectionLogs = mapped;
          _inspectionLoading = false;
        });
      } else {
        _inspectionError =
        '점검로그를 불러오지 못했습니다: ${logsResponse.statusCode}';
      }
    } catch (e) {
      _inspectionError = '점검로그를 가져오는 중 오류가 발생했습니다: $e';
    } finally {
      setState(() {
        _inspectionLoading = false;
      });
    }
  }

  Future<void> _refreshInspectionLogs() async {
    // 강제로 상태를 초기화하고 새로고침
    setState(() {
      _inspectionLoading = true;
      _inspectionError = null;
    });
    await _fetchInspectionLogs();
  }

  void _setCarImages(String carName) {
    setState(() {
      int numImages;
      String basePath;
      switch (carName) {
        case 'xm3':
          numImages = 36;
          basePath = 'assets/xm3/';
          break;
        case '그랜저':
          numImages = 36;
          basePath = 'assets/그랜저/';
          break;
        case '재규어':
          numImages = 30;
          basePath = 'assets/재규어/';
          break;
        case '모닝':
          numImages = 36;
          basePath = 'assets/모닝/';
          break;
        case '스포티지':
          numImages = 36;
          basePath = 'assets/스포티지/';
          break;
        case '아반떼':
          numImages = 36;
          basePath = 'assets/아반떼/';
          break;
        case '코나':
          numImages = 36;
          basePath = 'assets/코나/';
          break;
        case '투싼':
          numImages = 36;
          basePath = 'assets/투싼/';
          break;
        default:
          numImages = 0;
          basePath = '';
      }
      _currentCarImagePaths =
          List.generate(numImages, (i) => '$basePath${i + 1}.png');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final car = ref.watch(currentCarProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (car != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarInfoPage()),
                );
              },
              child: CarViewerSection(imagePaths: _currentCarImagePaths),
            ),
          const SizedBox(height: 20),

          if (_carVin != null)
            ConsumablesSection(consumables: _consumables, vin: _carVin!),

          const SizedBox(height: 24),

          // 🚗 주행로그 Section
          Text(
            '주행 로그',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_mileageLoading)
            const Center(child: CircularProgressIndicator())
          else if (_mileageError != null)
            Center(child: Text(_mileageError!))
          else if (_mileageLogs.isEmpty)
              Card(
                color: const Color(0xFF232326),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.article_outlined,
                      color: Colors.white70),
                  title: const Text('주행 기록이 없습니다',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('상세 화면으로 이동합니다',
                      style: TextStyle(color: Colors.grey)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DrivingRecordPage(logs: _mileageLogs),
                      ),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: _mileageLogs.length <= 2 
                    ? (_mileageLogs.length * 70.0) + 10.0  // 각 카드 높이(70) + 마진(10)
                    : 150.0,  // 2개 초과시 고정 높이
                child: ListView.builder(
                  itemCount: _mileageLogs.length,
                  itemBuilder: (context, index) {
                    final log = _mileageLogs[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DrivingRecordPage(logs: _mileageLogs),
                          ),
                        );
                      },
                      child: Card(
                        color: const Color(0xFF232326),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(Icons.place,
                                  color: Colors.white54, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(log['distance'] ?? ''),
                                    const SizedBox(height: 6),
                                    Text(
                                      log['date'] ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
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

          // 🛠️ 점검로그 Section
          Text(
            '점검 로그',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_inspectionLoading)
            const Center(child: CircularProgressIndicator())
          else if (_inspectionError != null)
            Center(child: Text(_inspectionError!))
          else
                         Builder(
               builder: (context) {
                 final completedLogs = _inspectionLogs
                     .where((e) => e['status'] == '점검 완료')
                     .toList();

                 return Column(
                   children: [
                     // 다음 점검 일자
                     if (_pendingDate != null && _pendingDate!.isNotEmpty)
                       GestureDetector(
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => InspectionDetailPage(
                                 inspectionLogs: _inspectionLogs,
                                 vin: _carVin!,
                                 onRefresh: _refreshInspectionLogs,
                                 pendingDate: _pendingDate,
                               ),
                             ),
                           );
                         },
                         child: Card(
                           color: const Color(0xFF232326),
                           margin: const EdgeInsets.only(bottom: 10),
                           shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(14)),
                           child: Padding(
                             padding: const EdgeInsets.symmetric(
                                 vertical: 12, horizontal: 20),
                             child: Row(
                               children: [
                                 const Icon(Icons.schedule,
                                     color: Colors.white70, size: 24),
                                 const SizedBox(width: 14),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         _pendingDate!,
                                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                             color: Colors.white, fontWeight: FontWeight.bold),
                                       ),
                                       const SizedBox(height: 6),
                                       const Text('점검 예정',
                                           style: TextStyle(color: Colors.grey, fontSize: 12)),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       )
                     else
                       GestureDetector(
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => InspectionDetailPage(
                                 inspectionLogs: _inspectionLogs,
                                 vin: _carVin!,
                                 onRefresh: _refreshInspectionLogs,
                                 pendingDate: null,
                               ),
                             ),
                           );
                         },
                         child: Card(
                           color: const Color(0xFF232326),
                           margin: const EdgeInsets.only(bottom: 10),
                           shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(12)),
                           child: Padding(
                             padding: const EdgeInsets.symmetric(
                                 vertical: 12, horizontal: 20),
                             child: Row(
                               children: [
                                 const Icon(Icons.article_outlined,
                                     color: Colors.white70, size: 20),
                                 const SizedBox(width: 14),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       const Text('예정된 점검 없음',
                                           style: TextStyle(color: Colors.white)),
                                       const SizedBox(height: 6),
                                       const Text('상세 화면으로 이동합니다',
                                           style: TextStyle(color: Colors.grey)),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       ),

                     // 과거 이력
                     if (completedLogs.isNotEmpty)
                       GestureDetector(
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => InspectionDetailPage(
                                 inspectionLogs: _inspectionLogs,
                                 vin: _carVin!,
                                 onRefresh: _refreshInspectionLogs,
                                 pendingDate: _pendingDate,
                               ),
                             ),
                           );
                         },
                         child: Card(
                           color: const Color(0xFF232326),
                           margin: const EdgeInsets.only(bottom: 10),
                           shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(14)),
                           child: Padding(
                             padding: const EdgeInsets.symmetric(
                                 vertical: 12, horizontal: 20),
                             child: Row(
                               children: [
                                 const Icon(Icons.check_box,
                                     color: Colors.white54, size: 24),
                                 const SizedBox(width: 14),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         completedLogs.first['date'] ?? '',
                                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                             color: Colors.white, fontWeight: FontWeight.bold),
                                       ),
                                       const SizedBox(height: 6),
                                       Text(
                                         completedLogs.first['status'] ?? '',
                                         style: const TextStyle(color: Colors.grey, fontSize: 12),
                                       ),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       )
                     else
                       GestureDetector(
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => InspectionDetailPage(
                                 inspectionLogs: _inspectionLogs,
                                 vin: _carVin!,
                                 onRefresh: _refreshInspectionLogs,
                                 pendingDate: _pendingDate,
                               ),
                             ),
                           );
                         },
                         child: Card(
                           color: const Color(0xFF232326),
                           margin: const EdgeInsets.only(bottom: 10),
                           shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(12)),
                           child: Padding(
                             padding: const EdgeInsets.symmetric(
                                 vertical: 12, horizontal: 20),
                             child: Row(
                               children: [
                                 const Icon(Icons.article_outlined,
                                     color: Colors.white70, size: 20),
                                 const SizedBox(width: 14),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       const Text('완료된 점검 이력 없음',
                                           style: TextStyle(color: Colors.white)),
                                       const SizedBox(height: 6),
                                       const Text('상세 화면으로 이동합니다',
                                           style: TextStyle(color: Colors.grey)),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       ),
                   ],
                 );
               },
             ),
        ],
      ),
    );
  }
}