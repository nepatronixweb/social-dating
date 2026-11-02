import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable install id for multi-account fraud signals (`X-Device-Id`).
///
/// Survives sign-out so shared-device rings stay detectable. Not a secret
/// credential — still kept in secure storage to avoid casual wipe.
abstract interface class DeviceIdStore {
  Future<String> getOrCreate();
}

class SecureDeviceIdStore implements DeviceIdStore {
  SecureDeviceIdStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'device.install_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _newId();
    await _storage.write(key: _key, value: id);
    return id;
  }

  static String _newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex;
  }
}

class MemoryDeviceIdStore implements DeviceIdStore {
  MemoryDeviceIdStore([this._id]);

  String? _id;

  @override
  Future<String> getOrCreate() async {
    return _id ??= SecureDeviceIdStore._newId();
  }
}
