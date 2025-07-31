import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'token_repository.dart';

part 'auth_provider.g.dart';

/// accessToken이 있으면 true, 없으면 false
@riverpod
Future<bool> isLoggedIn(IsLoggedInRef ref) async {
  final repo = ref.read(tokenRepositoryProvider);
  final token = await repo.getAccessToken();
  return token != null && token.isNotEmpty;
}
