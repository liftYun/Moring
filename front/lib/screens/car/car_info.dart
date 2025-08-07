import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/base_scaffold.dart';
import 'package:moring/models/car.dart';
import 'package:moring/providers/api_client.dart'; // authDioProvider 위치

class CarInfoPage extends ConsumerStatefulWidget {
  final Car car;
  const CarInfoPage({Key? key, required this.car}) : super(key: key);

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
  }

  Future<bool> _deleteCarByVin(String vin) async {
    final dio = ref.read(authDioProvider);
    try {
      final response = await dio.delete('/api/v1/cars/$vin');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete failed: $e');
      return false;
    }
  }

  void _showDeleteConfirm(BuildContext context) {
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
                  // Modal의 높이 결정: 모달 내용의 높이에 맞게 (예: 200)
                  height: 220, // 또는 필요시 mainAxisSize: MainAxisSize.min
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
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
                    const SizedBox(height: 8),
                    const Text(
                      '삭제 시 입력된 모든 정보가 삭제됩니다.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context); // 삭제 모달 닫기
                              final success = await _deleteCarByVin(widget.car.vin);
                              if (success) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('차량이 성공적으로 삭제되었습니다.'),
                                  ),
                                );
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/carselection',
                                      (route) => false,
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                    Text('삭제에 실패했습니다. 관리자에게 문의하세요.'),
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

    return BaseScaffold(
      title: '차량 정보',
      withBottomNav: true,
      selectedIndex: _selectedIndex,
      onItemTapped: _onItemTapped,
      body: Column(
        children: [
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              color: Colors.white,
              width: double.infinity,
              height: 170,
              child: Image.asset(
                'assets/${widget.car.modelName.toLowerCase()}/11.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: cardDark,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.car.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                            const SizedBox(height: 3),
                            Text(
                              widget.car.vin,
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
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white10, thickness: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Model',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.car.modelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showDeleteConfirm(context);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF4A4A4A), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
