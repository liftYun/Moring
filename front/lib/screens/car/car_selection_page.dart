import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/car_provider.dart';
import 'package:moring/utils/base_scaffold.dart';
import '../root.dart';

/// 차량 선택 화면
class CarSelectionContainer extends ConsumerWidget {
  const CarSelectionContainer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) 전역 FutureProvider로 차량 목록 읽기
    final carsAsync = ref.watch(carListProvider);

    return carsAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('차량 정보를 가져올 수 없습니다.\n$err'))),

      data: (cars) {
        // 2) 차량이 없으면 No Car 페이지로
        if (cars.isEmpty) {
          Future.microtask(() =>
              Navigator.pushReplacementNamed(context, '/nocar'));
          return const Scaffold(); // 빈 화면
        }

        return BaseScaffold(
          title: '보유 차량',
          showNotificationButton: false,
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: cars.length,
            itemBuilder: (ctx, index) {
              final car = cars[index];
              return _CarCard(car: car, index: index);
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
    final demoCarImage = 'assets/$carName/4.png';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF23262B),
        borderRadius: BorderRadius.circular(18),
      ),
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 텍스트 + 버튼
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(car.nickname,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(car.modelName,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      // 3) 선택 인덱스를 전역 상태에 저장
                      ref.read(selectedCarIndexProvider.notifier).state = index;
                      // 4) RootPage 로 넘어가기 (currentVinProvider 가 pick up)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RootPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: const Text('선택하기'),
                  ),
                ),
              ],
            ),
          ),
          // 이미지
          Positioned(
            top: -50,
            right: -40,
            child: SizedBox(
              width: 200,
              height: 120,
              child: Image.asset(demoCarImage, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}
