import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import'package:moring/providers/secure_storage.dart';

part 'secure_storage_provider.g.dart';

// FlutterSecureStorage 인스턴스를 제공
@riverpod
FlutterSecureStorage storage(StorageRef ref) {
  return const FlutterSecureStorage();
}

// SecureStorage 래퍼 인스턴스를 제공
@riverpod
SecureStorage secureStorage(SecureStorageRef ref) {
  // storageProvider는 위에서 정의된 storage()의 결과물
  final storage = ref.read(storageProvider);
  return SecureStorage(storage: storage);
}
