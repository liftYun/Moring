import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/custom_app_bar.dart'; // 경로는 프로젝트 맞게 조정
import 'package:moring/screens/root.dart';
import 'package:moring/providers/current_car_provider.dart';

class RegistrationCompletePage extends ConsumerWidget {
  const RegistrationCompletePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = ref.watch(currentCarProvider);

    if (car == null) {
      return Scaffold(
        appBar: CustomAppBar(
          title: '차량 등록',
          onBackButtonPressed: () => Navigator.pop(context),
        ),
        body: const Center(child: Text('등록된 차량 정보가 없습니다.')),
      );
    }

    String carImagePath = 'assets/${car.modelName.toLowerCase()}/11.png';

    return Scaffold(
      appBar: CustomAppBar(
        title: '차량 등록 완료',
        onBackButtonPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 22),
            // 차량 이미지 + 효과
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width + 40,
                  height: 250,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0x40FFFFFF),
                        Color(0x00FFFFFF),
                        Color(0x22181A20),
                        Color(0xFF181A20),
                      ],
                      center: Alignment(0, 0.4),
                      radius: 1.1,
                      stops: [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                Container(
                  width: 220,
                  height: 65,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.30),
                        blurRadius: 70,
                        spreadRadius: 25,
                        offset: const Offset(0, 24),
                      ),
                      BoxShadow(
                        color: Colors.black87.withOpacity(0.28),
                        blurRadius: 35,
                        spreadRadius: 2,
                        offset: const Offset(0, 44),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 340,
                  height: 140,
                  child: Image.asset(
                    carImagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              '차량 등록 완료',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '차량이 성공적으로 등록되었습니다.\n이제 차량 관련 모든 정보를 확인할 수 있습니다.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RootPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
