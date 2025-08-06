/// providers/current_car_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/utils/iterable_extensions.dart';
import 'package:moring/models/car.dart';
import 'car_provider.dart';

/// carListProvider 와 currentVinProvider 를 합쳐서
/// 현재 선택된 Car 객체를 제공하는 Provider
final currentCarProvider = Provider<Car?>((ref) {
  final cars = ref.watch(carListProvider).maybeWhen(
    data: (list) => list,
    orElse: () => <Car>[],
  );
  final vin = ref.watch(currentVinProvider);
  return cars.firstWhereOrNull((c) => c.vin == vin);
});
