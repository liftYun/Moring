import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/providers/user_provider.dart';

import 'package:moring/models/car.dart';
import '../services/car_service.dart';
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
final selectedCarIndexProvider = StateProvider.autoDispose<int>((_) => 0);

final currentVinProvider = Provider.autoDispose<String?>((ref) {
  final carsAsync = ref.watch(carListProvider);
  final idx = ref.watch(selectedCarIndexProvider);
  return carsAsync.maybeWhen(
    data: (cars) => (idx >= 0 && idx < cars.length) ? cars[idx].vin : null,
    orElse: () => null,
  );
});