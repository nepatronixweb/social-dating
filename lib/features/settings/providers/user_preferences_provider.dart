import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_preferences.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/services/service_providers.dart';

/// Device-only notification, privacy and accessibility choices.
class UserPreferencesNotifier extends Notifier<UserPreferences> {
  @override
  UserPreferences build() =>
      ref.read(localPreferencesServiceProvider).userPreferences;

  Future<void> update(
    UserPreferences Function(UserPreferences current) fn,
  ) async {
    final next = fn(state);
    state = next;
    await ref.read(settingsRepositoryProvider).savePreferences(next);
  }
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferences>(
      UserPreferencesNotifier.new,
    );
