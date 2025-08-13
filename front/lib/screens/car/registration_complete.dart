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
        // onBackButtonPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.06, // 화면 너비의 6%
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                         SizedBox(height: MediaQuery.of(context).size.height * 0.028), // 화면 높이의 2.8%
            // 차량 이미지 + 효과
            Stack(
              alignment: Alignment.center,
              children: [
                                 Container(
                   width: MediaQuery.of(context).size.width + MediaQuery.of(context).size.width * 0.1, // 화면 너비 + 10%
                   height: MediaQuery.of(context).size.height * 0.31, // 화면 높이의 31%
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
                   width: MediaQuery.of(context).size.width * 0.55, // 화면 너비의 55%
                   height: MediaQuery.of(context).size.height * 0.08, // 화면 높이의 8%
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
                   width: MediaQuery.of(context).size.width * 0.85, // 화면 너비의 85%
                   height: MediaQuery.of(context).size.height * 0.16, // 화면 높이의 16%
                  child: Image.asset(
                    carImagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
                         SizedBox(height: MediaQuery.of(context).size.height * 0.05), // 화면 높이의 5%
            const Text(
              '차량 등록 완료',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
                         SizedBox(height: MediaQuery.of(context).size.height * 0.02), // 화면 높이의 2%
            const Text(
              '차량이 성공적으로 등록되었습니다.\n이제 차량 관련 모든 정보를 확인할 수 있습니다.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
                         SizedBox(height: MediaQuery.of(context).size.height * 0.045), // 화면 높이의 4.5%
            SizedBox(
              width: double.infinity,
                             height: MediaQuery.of(context).size.height * 0.06, // 화면 높이의 6%
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
                  backgroundColor: const Color(0xFF50C878),
                  foregroundColor: Colors.black,
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
