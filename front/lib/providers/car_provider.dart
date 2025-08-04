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
