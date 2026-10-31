import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/session_snapshot.dart';
import '../models/user_preferences.dart';

/// Typed access to non-sensitive local preferences.
class LocalPreferencesService {
  const LocalPreferencesService(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode get themeMode {
    final stored = _prefs.getString(StorageKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(StorageKeys.themeMode, mode.name);

  /// The last saved session state, or `null` if none (or it is unreadable).
  SessionSnapshot? get sessionSnapshot =>
      SessionSnapshot.decode(_prefs.getString(StorageKeys.sessionSnapshot));

  Future<void> saveSessionSnapshot(SessionSnapshot snapshot) =>
      _prefs.setString(StorageKeys.sessionSnapshot, snapshot.encode());

  Future<void> clearSessionSnapshot() =>
      _prefs.remove(StorageKeys.sessionSnapshot);

  /// Notification, privacy and accessibility choices. Mock: this device only.
  UserPreferences get userPreferences =>
      UserPreferences.decode(_prefs.getString(StorageKeys.userPreferences));

  Future<void> setUserPreferences(UserPreferences preferences) =>
      _prefs.setString(StorageKeys.userPreferences, preferences.encode());

  String? get pendingReferralCode {
    final stored = _prefs.getString(StorageKeys.pendingReferralCode);
    if (stored == null || stored.trim().isEmpty) return null;
    return stored.trim();
  }

  Future<void> setPendingReferralCode(String? code) async {
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _prefs.remove(StorageKeys.pendingReferralCode);
      return;
    }
    await _prefs.setString(StorageKeys.pendingReferralCode, trimmed);
  }

  /// Extended personal-information JSON. Device mock until the API lands.
  String? get personalProfileJson =>
      _prefs.getString(StorageKeys.personalProfile);

  Future<void> setPersonalProfileJson(String json) =>
      _prefs.setString(StorageKeys.personalProfile, json);
}
