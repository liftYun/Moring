import 'dart:ui';
import 'package:flutter/material.dart';

class CarNotRegisteredPage extends StatelessWidget {
  const CarNotRegisteredPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 모달 높이 추후 맞춤 조정 가능
    const double modalHeight = 440;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 블러 처리될 부분 (중앙 텍스트 등 전체 화면)
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '등록된 차량이 없습니다.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 2. 하단 모달 올라오기 전, 블러 효과 오버레이
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withOpacity(0.1),
                    height: MediaQuery.of(context).size.height - modalHeight,
                  ),
                ),
              ),
            ),
          ),
          // 3. 하단 모달 (바텀시트) 부분, 가장 위에! 블러 미적용
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              decoration: const BoxDecoration(
                color: Color(0xFF22262B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '아직 차량을 연결하지 않으셨나요?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '지금 연결하고 알림을 받아보세요!',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/carRegistration');
                      },
                      child: Text(
                        '차량 등록하러 가기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
