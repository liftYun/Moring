import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moring/models/user_info.dart';
import 'package:moring/services/user_service.dart';

final userInfoProvider = FutureProvider.autoDispose<UserInfo>((ref) {
  final service = ref.read(userServiceProvider);
  return service.getUserInfo();
});
