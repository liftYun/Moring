import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moring/providers/secure_storage_provider.dart';
import 'package:moring/providers/secure_storage.dart';  // SecureStorage 클래스

part 'token_repository.g.dart';

class TokenRepository {
  final SecureStorage _wrapper;
  TokenRepository(this._wrapper);

  Future<void> saveAccessToken(String token) =>
      _wrapper.saveAccessToken(token);

  Future<String?> getAccessToken() =>
      _wrapper.getAccessToken();

  Future<void> deleteAccessToken() =>
      _wrapper.deleteAccessToken();

  Future<void> saveRefreshToken(String token) =>
      _wrapper.saveRefreshToken(token);

  Future<String?> getRefreshToken() =>
      _wrapper.getRefreshToken();

  Future<void> deleteRefreshToken() =>
      _wrapper.deleteRefreshToken();

  Future<void> deleteAllTokens() async {
    await deleteAccessToken();
    await deleteRefreshToken();
  }
}

@riverpod
TokenRepository tokenRepository(TokenRepositoryRef ref) {
  // storageProvider 가 아니라 secureStorageProvider 를 주입
  final wrapper = ref.watch(secureStorageProvider);
  return TokenRepository(wrapper);
}
