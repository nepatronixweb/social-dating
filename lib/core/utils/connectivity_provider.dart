import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app should present itself as offline.
///
/// Phase 1 has no real connectivity detection (and no network at all), so this
/// is only ever changed manually, e.g. from the debug controls, to exercise
/// the offline banner. A real implementation can later drive it from a
/// connectivity plugin without touching any UI.
class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOffline(bool value) => state = value;
}

final isOfflineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);
