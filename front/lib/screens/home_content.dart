import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:moring/models/consumable.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/widgets/car_viewer_section.dart';
import 'package:moring/widgets/consumables_section.dart';
import 'package:moring/widgets/driving_log_section.dart';

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

  final List<Map<String, String>> todayLogs = [
    {'distance': '15.2 mi', 'time': '12:30 PM - 1:00 PM'},
  ];
  final List<Map<String, String>> yesterdayLogs = [
    {'distance': '22.5 mi', 'time': '9:00 AM - 9:45 AM'},
    {'distance': '5.0 mi', 'time': '5:30 PM - 5:45 PM'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final car = ref.read(currentCarProvider);
      if (car != null) {
        _carVin = car.vin;
        _setCarImages(car.modelName.toLowerCase());
        _fetchConsumables();
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
          if (car != null) CarViewerSection(imagePaths: _currentCarImagePaths),
          const SizedBox(height: 20),
          if (_carVin != null)
            ConsumablesSection(consumables: _consumables, vin: _carVin!),
          const SizedBox(height: 20),
          DrivingLogSection(title: 'Today', logs: todayLogs),
          const SizedBox(height: 20),
          DrivingLogSection(title: 'Yesterday', logs: yesterdayLogs),
        ],
      ),
    );
  }
}
