import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moring/models/car.dart';
import 'package:moring/utils/custom_app_bar.dart';
import 'package:moring/utils/bottom_nav_bar.dart';

class CarSelectionPage extends ConsumerStatefulWidget {
  const CarSelectionPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CarSelectionPage> createState() => _CarSelectionPageState();
}

class _CarSelectionPageState extends ConsumerState<CarSelectionPage> {
  int _selectedIndex = 0;

  final List<Car> _cars = [
    Car(
      vin: '1',
      nickname: '내 첫차',
      modelName: 'Hyundai Kona',
      imgUrl: 'assets/xm3/xm3_4.png',
    ),
    Car(
      vin: '2',
      nickname: '두번째 차',
      modelName: 'Kia Sorento',
      imgUrl: 'assets/그렌저/4.png',
    ),
  ];

  Car? _selectedCarForDropdown;

  @override
  void initState() {
    super.initState();
    if (_cars.isNotEmpty) {
      _selectedCarForDropdown = _cars[0];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToCarDetail(Car car) {
    Navigator.pushNamed(
      context,
      '/carDetail',
      arguments: {'car': car},
    );
  }

  Widget buildCarCard(Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF23262B),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(20),
            height: 160,
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
                  style:
                  const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                Center(
                  child: SizedBox(
                    width: 120,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('선택하기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (car.imgUrl.isNotEmpty)
            Positioned(
              top: -70,
              right: -60,
              child: Image.asset(
                car.imgUrl,
                width: 300,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 100),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '보유 차량',
        onBackButtonPressed: () => Navigator.pop(context),
        showCarDropdown: true,
        availableCars: _cars.map((c) => c.modelName).toList(),
        selectedCar: _selectedCarForDropdown?.modelName,
        onCarChanged: (newValue) {
          if (newValue != null) {
            setState(() {
              _selectedCarForDropdown =
                  _cars.firstWhere((c) => c.modelName == newValue);
            });
          }
        },
      ),
      body: _cars.isEmpty
          ? const Center(
          child: Text(
            '등록된 차량이 없습니다.',
            style: TextStyle(color: Colors.white),
          ))
          : ListView.builder(
          itemCount: _cars.length,
          itemBuilder: (context, index) {
            final car = _cars[index];
            return buildCarCard(car);
          }),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
