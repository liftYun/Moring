import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/utils/base_scaffold.dart';
import '../root.dart';
import 'package:moring/providers/current_car_provider.dart';

/// 차량 선택 화면
class CarSelectionContainer extends ConsumerWidget {
  const CarSelectionContainer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(carListProvider);

    return carsAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('차량 정보를 가져올 수 없습니다.\n$err'))),

      data: (cars) {
        if (cars.isEmpty) {
          Future.microtask(() =>
              Navigator.pushReplacementNamed(context, '/nocar'));
          return const Scaffold();
        }

        return BaseScaffold(
          title: '보유 차량',
          showNotificationButton: false,
          body: ListView.builder(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
            itemCount: cars.length + 1,
            itemBuilder: (ctx, index) {
              if (index < cars.length) {
                final car = cars[index];
                return _CarCard(car: car, index: index);
              } else {
                return Center(
                  child: IconButton(
                    iconSize: MediaQuery.of(context).size.width * 0.1,
                    icon: const Icon(Icons.add, color: Colors.white24),
                    tooltip: '차량 등록',
                    onPressed: () {
                      Navigator.pushNamed(ctx, '/registration');
                    },
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

/// 차량 카드 위젯
class _CarCard extends ConsumerWidget {
  final Car car;
  final int index;

  const _CarCard({required this.car, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carName = car.modelName.toLowerCase();
    final demoCarImage = 'assets/$carName/3.png';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ 이미지의 위치와 크기를 동적으로 설정하여, 화면 크기에 비례하여 커지도록 합니다.
    final topPosition = -screenHeight * 0.06;
    final rightPosition = -screenWidth * 0.1;
    final imageWidth = screenWidth * 0.6;
    final imageHeight = screenHeight * 0.2;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.025,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF23262B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 텍스트 + 버튼
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  car.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18, // ✅ 폰트 크기를 고정값으로 변경
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  car.modelName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15, // ✅ 폰트 크기를 고정값으로 변경
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(selectedCarIndexProvider.notifier).state = index;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RootPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.015,
                        horizontal: screenWidth * 0.06,
                      ),
                    ),
                    child: const Text('선택하기'),
                  ),
                ),
              ],
            ),
          ),
          // 이미지
          Positioned(
            top: topPosition,
            right: rightPosition,
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: Image.asset(demoCarImage, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}