import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage storage;
  SecureStorage({ required this.storage });

  Future<void> saveRefreshToken(String token) =>
      storage.write(key: 'refreshToken', value: token);

  Future<String?> getRefreshToken() =>
      storage.read(key: 'refreshToken');

  Future<void> deleteRefreshToken() =>
      storage.delete(key: 'refreshToken');

  Future<void> saveAccessToken(String token) =>
      storage.write(key: 'accessToken', value: token);

  Future<String?> getAccessToken() =>
      storage.read(key: 'accessToken');

  Future<void> deleteAccessToken() =>
      storage.delete(key: 'accessToken');

}
