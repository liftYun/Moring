import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/api_client.dart'; // authDioProvider 위치
import 'package:moring/providers/car_provider.dart';
import 'package:moring/providers/current_car_provider.dart';

class CarInfoPage extends ConsumerStatefulWidget {
  const CarInfoPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CarInfoPage> createState() => _CarInfoPageState();
}

class _CarInfoPageState extends ConsumerState<CarInfoPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // TODO: 페이지 전환 로직 추가
    });
    
    // 페이지 전환 로직
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/root');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/navigation');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/driving_record');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/mypage');
        break;
    }
  }

  Future<bool> _deleteCarByVin(String vin) async {
    final dio = ref.read(authDioProvider);
    try {
      final response = await dio.delete('/api/v1/cars/$vin');
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ 차량 삭제 성공: $vin');
        return true;
      } else {
        debugPrint('❌ 차량 삭제 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 차량 삭제 중 오류 발생: $e');
      return false;
    }
  }

  void _showDeleteConfirm(BuildContext context, String vin) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Stack(
            children: [
              // 블러 처리 모달 바닥에만 적용
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.transparent,
                  height: MediaQuery.of(context).size.height * 0.275, // 화면 높이의 27.5%
                ),
              ),
              Container(
                margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04), // 화면 너비의 4%
                padding: EdgeInsets.symmetric(
                  vertical: MediaQuery.of(context).size.height * 0.035, // 화면 높이의 3.5%
                  horizontal: MediaQuery.of(context).size.width * 0.045, // 화면 너비의 4.5%
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF23262B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '정말로 삭제하시겠습니까?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01), // 화면 높이의 1%
                    const Text(
                      '삭제 시 입력된 모든 정보가 삭제됩니다.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03), // 화면 높이의 3%
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: EdgeInsets.symmetric(
                                vertical: MediaQuery.of(context).size.height * 0.016, // 화면 높이의 1.6%
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // 아니오: 모달 닫기
                            },
                            child: const Text('아니요'),
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.04), // 화면 너비의 4%
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: MediaQuery.of(context).size.height * 0.016, // 화면 높이의 1.6%
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context); // 삭제 모달 닫기
                              
                              try {
                                final success = await _deleteCarByVin(vin);
                                if (success) {
                                  // Provider들을 순서대로 새로고침
                                  ref.invalidate(carListProvider);
                                  ref.invalidate(currentVinProvider);
                                  
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('차량이 성공적으로 삭제되었습니다.'),
                                    ),
                                  );
                                  
                                  // 차량 선택 페이지로 이동
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/carselection',
                                    (route) => false,
                                  );
                                } else {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('삭제에 실패했습니다. 다시 시도해주세요.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('❌ 삭제 처리 중 오류: $e');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('삭제 중 오류가 발생했습니다: $e'),
                                  ),
                                );
                              }
                            },
                            child: const Text('네'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cardDark = Color(0xFF23262B);

    final car = ref.watch(currentCarProvider);

    if (car == null) {
      return BaseScaffold(
        title: '차량 정보',
        body: const Center(child: Text('차량 정보가 없습니다.')),
      );
    }

    return BaseScaffold(
      title: '차량 정보',
      withBottomNav: true,
      selectedIndex: _selectedIndex,
      onItemTapped: _onItemTapped,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.04), // 화면 높이의 4%
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.2, // 화면 높이의 20%
              child: Image.asset(
                'assets/${car.modelName.toLowerCase()}/10.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: cardDark,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06, // 화면 너비의 6%
                vertical: MediaQuery.of(context).size.height * 0.03, // 화면 높이의 3%
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.022), // 화면 높이의 2.2%
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VIN',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.004), // 화면 높이의 0.4%
                            Text(
                              car.vin,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.012), // 화면 높이의 1.2%
                  const Divider(color: Colors.white10, thickness: 1),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.012), // 화면 높이의 1.2%
                  const Text(
                    'Model',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.004), // 화면 높이의 0.4%
                  Text(
                    car.modelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.012), // 화면 높이의 1.2%
                  const Divider(color: Colors.white10, thickness: 1),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.012), // 화면 높이의 1.2%
                  // const Text(
                  //   '등록일',
                  //   style: TextStyle(
                  //     color: Colors.white54,
                  //     fontSize: 13,
                  //   ),
                  // ),
                  // SizedBox(height: MediaQuery.of(context).size.height * 0.004), // 화면 높이의 0.4%
                  // Text(
                  //   car.registeredAt ?? '등록일 없음',
                  //   style: const TextStyle(
                  //     color: Colors.white,
                  //     fontSize: 15,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  // ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showDeleteConfirm(context, car.vin);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF4A4A4A), width: 2),
                            padding: EdgeInsets.symmetric(
                              vertical: MediaQuery.of(context).size.height * 0.017, // 화면 높이의 1.7%
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
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
