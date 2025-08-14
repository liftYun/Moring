import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/secure_storage.dart';
import 'package:moring/providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:moring/providers/secure_storage_provider.dart'; // 기존 SecureStorage 활용

import 'package:moring/models/car.dart';
import 'package:moring/services/car_service.dart';
import 'api_client.dart';

final carServiceProvider = Provider<CarService>((ref) {
  final dio = ref.read(authDioProvider);
  return CarService(dio);
});

final carListProvider = FutureProvider.autoDispose<List<Car>>((ref) async {
  final user = await ref.read(userInfoProvider.future);
  return ref.read(carServiceProvider).getMyCars(user.uuid);
});

/// 목록에서 선택된 인덱스를 저장 (기본 0)
final selectedCarIndexProvider = StateProvider<int>((_) => 0);

/// 🆕 VIN 자동 저장을 위한 StateNotifier
class VinNotifier extends StateNotifier<String?> {
  final SecureStorage _secureStorage;
  
  VinNotifier(this._secureStorage) : super(null);
  
  /// VIN 업데이트 및 자동 저장
  Future<void> updateVin(String? newVin) async {
    if (newVin != null && newVin.isNotEmpty && newVin != state) {
      state = newVin;
      try {
        await _secureStorage.storage.write(key: 'currentVin', value: newVin);
        debugPrint('✅ VIN 자동 저장 완료: $newVin');
      } catch (e) {
        debugPrint('❌ VIN 자동 저장 실패: $e');
      }
    }
  }
}

/// 🆕 VIN 자동 저장 Provider
final vinNotifierProvider = StateNotifierProvider<VinNotifier, String?>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return VinNotifier(secureStorage);
});

final currentVinProvider = StateProvider.autoDispose<String?>((ref) {
  final carsAsync = ref.watch(carListProvider);
  final idx = ref.watch(selectedCarIndexProvider);

  // return carsAsync.maybeWhen(
  //   data: (cars) => (idx >= 0 && idx < cars.length) ? cars[idx].vin : null,
  //   orElse: () => null,
  // );

  final currentVin = carsAsync.maybeWhen(
    data: (cars) => (idx >= 0 && idx < cars.length) ? cars[idx].vin : null,
    orElse: () => null,
  );

  // 🆕 VIN이 변경되면 자동으로 저장 (기존 SecureStorage 활용)
  if (currentVin != null && currentVin.isNotEmpty) {
    // 비동기 저장 (UI 블로킹 방지)
    Future.microtask(() async {
      try {
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.storage.write(key: 'currentVin', value: currentVin);
        debugPrint('✅ VIN 자동 저장 완료 (기존 구조 활용): $currentVin');
      } catch (e) {
        debugPrint('❌ VIN 자동 저장 실패: $e');
      }
    });
  }

  return currentVin;
});

/// 🆕 앱 시작 시 저장된 VIN 복원 (기존 SecureStorage 활용)
final restoreVinProvider = FutureProvider<void>((ref) async {
  try {
    final secureStorage = ref.read(secureStorageProvider);
    final savedVin = await secureStorage.storage.read(key: 'currentVin');
    
    if (savedVin != null && savedVin.isNotEmpty) {
      debugPrint('🔄 저장된 VIN 복원: $savedVin');
      
      // 저장된 VIN에 해당하는 차량의 인덱스 찾기
      final carsAsync = await ref.read(carListProvider.future);
      final vinIndex = carsAsync.indexWhere((car) => car.vin == savedVin);
      
      if (vinIndex >= 0) {
        ref.read(selectedCarIndexProvider.notifier).state = vinIndex;
        debugPrint('✅ VIN 복원 및 차량 선택 완료: 인덱스 $vinIndex');
      }
    }
  } catch (e) {
    debugPrint('❌ VIN 복원 실패: $e');
  }
});