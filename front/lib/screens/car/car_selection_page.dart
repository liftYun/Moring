import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:moring/models/car.dart'; // Car 모델 임포트
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/bottom_nav_bar.dart';
import 'package:moring/providers/api_client.dart';
import 'package:moring/providers/user_provider.dart';
import 'package:moring/utils/base_scaffold.dart';

import '../home_page.dart';
import '../root.dart';

class CarSelectionContainer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfoAsync = ref.watch(userInfoProvider);

    return userInfoAsync.when(
      data: (userInfo) => CarSelectionPage(memberUuid: userInfo.uuid),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('사용자 정보를 가져오지 못했습니다.\n$e'))),
    );
  }
}


class CarSelectionPage extends ConsumerStatefulWidget {
  final String memberUuid;

  const CarSelectionPage({Key? key, required this.memberUuid}) : super(key: key);

  @override
  ConsumerState<CarSelectionPage> createState() => _CarSelectionPageState();
}

class _CarSelectionPageState extends ConsumerState<CarSelectionPage> {
  List<Car> _cars = [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;
  Car? _selectedCarForDropdown;

  @override
  void initState() {
    super.initState();
    _loadCarList();
  }

  Future<List<Car>> fetchCarList(Dio dio, String memberUuid) async {
    final response = await dio.get(
      '/api/v1/cars/$memberUuid/list',
      options: Options(headers: {'memberUuid': memberUuid}),
    );

    if (response.statusCode == 200 && response.data['isSuccess'] == true) {
      final List list = response.data['result'] as List;
      return list
          .map((e) =>
          Car(
            vin: e['vin'] ?? '',
            nickname: e['nickname'] ?? '',
            modelName: e['modelName'] ?? '',
            imgUrl: '', // 이미지 사용 X
          ))
          .toList();
    }
    throw Exception('차량 리스트 불러오기 실패');
  }

  Future<void> _loadCarList() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dio = ref.read(authDioProvider); // Dio provider

    try {
      final carList = await fetchCarList(dio, widget.memberUuid);
      setState(() {
        _cars = carList;
      });

      if (_cars.isEmpty) {
        Future.microtask(() {
          Navigator.pushReplacementNamed(context, '/nocar');
        });
        return;
      }

      if (_cars.isNotEmpty) {
        _selectedCarForDropdown = _cars[0];
      }
    } catch (e) {
      setState(() {
        _error = '차량 정보를 불러오는 데 실패했습니다.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // void _navigateToCarDetail(Car car) {
  //   Navigator.pushNamed(context, '/root', arguments: {'car': car});
  // }
  void _navigateToCarDetail(Car car) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RootPage(initialCar: car),
      ),
    );
  }

  Widget buildCarCard(Car car) {
    // 등록된 차량 모델 이름에 맞춰 동일한 사진을 띄움
    String carName = car.modelName.toLowerCase();
    debugPrint('car_selection Name : $carName');
    final String demoCarImage = 'assets/$carName/4.png'; // 에셋(로컬) 이미지 경로 예시

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF23262B),
        borderRadius: BorderRadius.circular(18),
      ),
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  car.modelName,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                Center(
                  child: SizedBox(
                    width: 120,
                    child: OutlinedButton(
                      onPressed: () {
                        _navigateToCarDetail(car);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('선택하기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: SizedBox(
              width: 300,
              height: 180,
              child: Image.asset( // 만약 네트워크 이미지라면 Image.network로 변경
                demoCarImage,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '보유 차량',
      withBottomNav: true,
      selectedIndex: _selectedIndex,
      onItemTapped: _onItemTapped,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
          ? Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      )
          : ListView.builder(
        itemCount: _cars.length,
        itemBuilder: (context, index) {
          final car = _cars[index];
          return buildCarCard(car);
        },
      )),
    );
  }
}

