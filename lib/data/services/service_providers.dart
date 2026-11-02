import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'device_id_store.dart';
import 'local_preferences_service.dart';
import 'share_port.dart';
import 'token_storage.dart';

/// Must be overridden in `ProviderScope` with the instance loaded at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  ),
);

final localPreferencesServiceProvider = Provider<LocalPreferencesService>(
  (ref) => LocalPreferencesService(ref.watch(sharedPreferencesProvider)),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final deviceIdStoreProvider = Provider<DeviceIdStore>(
  (ref) => SecureDeviceIdStore(),
);

/// Lazy: nothing is created (and no I/O happens) until first read.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokens: ref.watch(tokenStorageProvider),
    devices: ref.watch(deviceIdStoreProvider),
  ),
);

/// Opens the system share sheet. Tests override with a recording fake.
final sharePortProvider = Provider<SharePort>((ref) => const SystemSharePort());
