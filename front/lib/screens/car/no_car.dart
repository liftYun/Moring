import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moring/utils/base_scaffold.dart';

class CarNotRegisteredPage extends StatefulWidget {
  const CarNotRegisteredPage({Key? key}) : super(key: key);

  @override
  _CarNotRegisteredPageState createState() => _CarNotRegisteredPageState();
}

class _CarNotRegisteredPageState extends State<CarNotRegisteredPage> {
  @override
  void initState() {
    super.initState();
    // 첫 번째 프레임 이후에 모달을 보여줌으로써 애니메이션 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRegisterCarModal(context);
    });
  }

  void _showRegisterCarModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Stack(
          children: [
            // 1. 블러 처리 레이어
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.transparent),
            ),
            // 2. 모달 내용
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 230,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
                                 decoration: BoxDecoration(
                   color: const Color(0xFF23262B),
                   borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '아직 차량을 연결하지 않으셨나요?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '지금 연결하고 알림을 받아보세요!',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF50C878),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // 모달 닫기
                          Navigator.pushNamed(context, '/registration'); // 차량 등록 페이지로 이동
                        },
                        child: const Text(
                          '차량 등록하러 가기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '차량 등록',
      showNotificationButton: false,
      showBack: true,
      onBackButtonPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
      body: Center(
        child: Text(
          '등록된 차량이 없습니다.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
