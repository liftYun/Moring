// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod 임포트
// import 'package:dio/dio.dart';
//
// import 'package:moring/models/vehicle.dart';
// import 'package:moring/utils/custom_app_bar.dart';
// import 'package:moring/utils/bottom_nav_bar.dart';
// import 'package:moring/providers/api_client.dart'; // authDioProvider를 위해 임포트
// import 'package:moring/screens/home_page.dart'; // HomePage 임포트
//
// class VehicleSelectionPage extends ConsumerStatefulWidget {
//   const VehicleSelectionPage({Key? key}) : super(key: key);
//
//   @override
//   ConsumerState<VehicleSelectionPage> createState() => _VehicleSelectionPageState();
// }
//
// class _VehicleSelectionPageState extends ConsumerState<VehicleSelectionPage> {
//   int _selectedIndex = 0;
//   bool _isLoading = true;
//   String? _errorMessage;
//   List<Vehicle> _vehicles = [];
//   Vehicle? _selectedVehicleForDropdown;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchVehicles();
//   }
//
//   Future<void> _fetchVehicles() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       // 🔑 이제 ConsumerStatefulWidget이므로 ref를 사용할 수 있습니다.
//       final dio = ref.read(authDioProvider);
//       // final response = await dio.get('/api/v1/cars/{f19f7658-6b86-11f0-8ea9-ea7f6f85ec62}/list');
//
//       if (response.statusCode == 200) {
//         final List<dynamic> jsonList = response.data['data'];
//         _vehicles = jsonList.map((json) => Vehicle.fromJson(json)).toList();
//         if (_vehicles.isNotEmpty) {
//           _selectedVehicleForDropdown = _vehicles.first;
//         }
//       } else {
//         _errorMessage = '차량 목록을 불러오는데 실패했습니다: ${response.statusCode}';
//         _vehicles = [];
//       }
//     } on DioException catch (e) {
//       _errorMessage = '네트워크 오류: ${e.message}';
//       _vehicles = [];
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }
//
//   void _navigateToVehicleDetail(Vehicle vehicle) {
//     Navigator.pushNamed(
//       context,
//       '/vehicleDetail',
//       arguments: {'vehicle': vehicle},
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (_errorMessage != null) {
//       return Scaffold(
//         body: Center(child: Text('에러: $_errorMessage')),
//       );
//     }
//
//     return Scaffold(
//       appBar: CustomAppBar(
//         title: '차량 선택',
//         onBackButtonPressed: () => Navigator.pop(context),
//         showCarDropdown: true,
//         availableCars: _vehicles.map((v) => v.modelName).toList(),
//         selectedCar: _selectedVehicleForDropdown?.modelName,
//         onCarChanged: (newValue) {
//           if (newValue != null) {
//             setState(() {
//               _selectedVehicleForDropdown = _vehicles.firstWhere((v) => v.modelName == newValue);
//             });
//           }
//         },
//       ),
//       body: _vehicles.isEmpty
//           ? const Center(child: Text('등록된 차량이 없습니다.'))
//           : ListView.builder(
//         itemCount: _vehicles.length,
//         itemBuilder: (context, index) {
//           final vehicle = _vehicles[index];
//           return Card(
//             margin: const EdgeInsets.all(8.0),
//             child: ListTile(
//               title: Text(vehicle.nickname),
//               subtitle: Text(vehicle.modelName),
//               trailing: ElevatedButton(
//                 onPressed: () => _navigateToVehicleDetail(vehicle),
//                 child: const Text('Detail'),
//               ),
//             ),
//           );
//         },
//       ),
//       bottomNavigationBar: CustomBottomNavBar(
//         selectedIndex: _selectedIndex,
//         onItemTapped: _onItemTapped,
//       ),
//     );
//   }
// }