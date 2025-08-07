import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/widgets/car_viewer_section.dart';
import 'package:moring/widgets/consumables_section.dart';
import 'package:moring/screens/information/driving_record.dart';
import 'package:moring/screens/car/car_info.dart';

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

  // 주행로그용 state
  List<Map<String, dynamic>> _mileageLogs = [];
  bool _mileageLoading = true;
  String? _mileageError;

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
      final response = await dio.get('/api/v1/parts/status/${_carVin ?? "TEST_VIN"}');
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final List list = response.data['result'] as List;
        setState(() {
          _consumables = list.map((e) => Consumable.fromJson(e)).toList();
        });
      } else {
        setState(() {
          _error = '소모품을 불러오지 못했습니다: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = '소모품을 가져오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ 주행로그 페이징 호출
  Future<void> _fetchMileageLogs() async {
    setState(() {
      _mileageLoading = true;
      _mileageError = null;
    });
    try {
      final dio = ref.read(authDioProvider);
      final response = await dio.get('/api/v1/cars/${_carVin ?? "TEST_VIN"}/mileage-logs-paging?page=0&size=10');
      if (response.statusCode == 200 && response.data['isSuccess'] == true) {
        final List content = response.data['result']['content'] ?? [];
        setState(() {
          _mileageLogs = content.map((e) => {
            'distance': '${e['mileageKm']} km',
            'date': e['recordedDate'] ?? '',
          }).toList();
        });
      } else {
        setState(() {
          _mileageError = '주행로그를 불러오지 못했습니다: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _mileageError = '주행로그를 가져오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _mileageLoading = false;
      });
    }
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
        default:
          numImages = 0;
          basePath = '';
      }
      _currentCarImagePaths = List.generate(numImages, (i) => '$basePath${i + 1}.png');
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
          Text('주행 로그', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_mileageLoading)
            const Center(child: CircularProgressIndicator())
          else if (_mileageError != null)
            Center(child: Text(_mileageError!))
          else
            SizedBox(
              height: 110, // 2개만 보이게
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: _mileageLogs.length,
                itemBuilder: (context, idx) {
                  final log = _mileageLogs[idx];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DrivingRecordPage(logs: _mileageLogs),
                        ),
                      );
                    },
                    child: Card(
                      color: const Color(0xFF232326),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.place, color: Colors.white54, size: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['distance'] ?? '',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    log['date'] ?? '',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
        ],
      ),
    );
  }
}
