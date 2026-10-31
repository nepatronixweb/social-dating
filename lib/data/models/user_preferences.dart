import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/settings_rules.dart';

/// Notification, privacy and accessibility choices stored on this device.
///
/// Persistence is mock: SharedPreferences on the device only. No push token,
/// reminder schedule or remote profile flag is updated.
@immutable
class UserPreferences {
  const UserPreferences({
    this.pushEnabled = true,
    this.notifyMatches = true,
    this.notifyLikes = true,
    this.notifyMessages = true,
    this.notifySystem = true,
    this.profileReminderDays = SettingsRules.defaultReminderDays,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = SettingsRules.defaultQuietStartMinutes,
    this.quietEndMinutes = SettingsRules.defaultQuietEndMinutes,
    this.showInDiscovery = true,
    this.showApproximateDistance = true,
    this.showActiveStatus = true,
    this.showOccupation = true,
    this.reduceMotion = false,
    this.boldText = false,
  });

  final bool pushEnabled;
  final bool notifyMatches;
  final bool notifyLikes;
  final bool notifyMessages;
  final bool notifySystem;

  /// 3, 4 or 5. Display-only; nothing is scheduled.
  final int profileReminderDays;

  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  final bool showInDiscovery;
  final bool showApproximateDistance;
  final bool showActiveStatus;
  final bool showOccupation;

  final bool reduceMotion;
  final bool boldText;

  UserPreferences copyWith({
    bool? pushEnabled,
    bool? notifyMatches,
    bool? notifyLikes,
    bool? notifyMessages,
    bool? notifySystem,
    int? profileReminderDays,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? showInDiscovery,
    bool? showApproximateDistance,
    bool? showActiveStatus,
    bool? showOccupation,
    bool? reduceMotion,
    bool? boldText,
  }) => UserPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    notifyMatches: notifyMatches ?? this.notifyMatches,
    notifyLikes: notifyLikes ?? this.notifyLikes,
    notifyMessages: notifyMessages ?? this.notifyMessages,
    notifySystem: notifySystem ?? this.notifySystem,
    profileReminderDays: profileReminderDays ?? this.profileReminderDays,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    showInDiscovery: showInDiscovery ?? this.showInDiscovery,
    showApproximateDistance:
        showApproximateDistance ?? this.showApproximateDistance,
    showActiveStatus: showActiveStatus ?? this.showActiveStatus,
    showOccupation: showOccupation ?? this.showOccupation,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    boldText: boldText ?? this.boldText,
  );

  String encode() => jsonEncode({
    'pushEnabled': pushEnabled,
    'notifyMatches': notifyMatches,
    'notifyLikes': notifyLikes,
    'notifyMessages': notifyMessages,
    'notifySystem': notifySystem,
    'profileReminderDays': profileReminderDays,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
    'showInDiscovery': showInDiscovery,
    'showApproximateDistance': showApproximateDistance,
    'showActiveStatus': showActiveStatus,
    'showOccupation': showOccupation,
    'reduceMotion': reduceMotion,
    'boldText': boldText,
  });

  static UserPreferences decode(String? raw) {
    if (raw == null || raw.isEmpty) return const UserPreferences();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final days =
          (map['profileReminderDays'] as num?)?.toInt() ??
          SettingsRules.defaultReminderDays;
      return UserPreferences(
        pushEnabled: map['pushEnabled'] as bool? ?? true,
        notifyMatches: map['notifyMatches'] as bool? ?? true,
        notifyLikes: map['notifyLikes'] as bool? ?? true,
        notifyMessages: map['notifyMessages'] as bool? ?? true,
        notifySystem: map['notifySystem'] as bool? ?? true,
        profileReminderDays: SettingsRules.reminderDayOptions.contains(days)
            ? days
            : SettingsRules.defaultReminderDays,
        quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
        quietStartMinutes:
            (map['quietStartMinutes'] as num?)?.toInt() ??
            SettingsRules.defaultQuietStartMinutes,
        quietEndMinutes:
            (map['quietEndMinutes'] as num?)?.toInt() ??
            SettingsRules.defaultQuietEndMinutes,
        showInDiscovery: map['showInDiscovery'] as bool? ?? true,
        showApproximateDistance:
            map['showApproximateDistance'] as bool? ?? true,
        showActiveStatus: map['showActiveStatus'] as bool? ?? true,
        showOccupation: map['showOccupation'] as bool? ?? true,
        reduceMotion: map['reduceMotion'] as bool? ?? false,
        boldText: map['boldText'] as bool? ?? false,
      );
    } catch (_) {
      return const UserPreferences();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.pushEnabled == pushEnabled &&
      other.notifyMatches == notifyMatches &&
      other.notifyLikes == notifyLikes &&
      other.notifyMessages == notifyMessages &&
      other.notifySystem == notifySystem &&
      other.profileReminderDays == profileReminderDays &&
      other.quietHoursEnabled == quietHoursEnabled &&
      other.quietStartMinutes == quietStartMinutes &&
      other.quietEndMinutes == quietEndMinutes &&
      other.showInDiscovery == showInDiscovery &&
      other.showApproximateDistance == showApproximateDistance &&
      other.showActiveStatus == showActiveStatus &&
      other.showOccupation == showOccupation &&
      other.reduceMotion == reduceMotion &&
      other.boldText == boldText;

  @override
  int get hashCode => Object.hash(
    pushEnabled,
    notifyMatches,
    notifyLikes,
    notifyMessages,
    notifySystem,
    profileReminderDays,
    quietHoursEnabled,
    quietStartMinutes,
    quietEndMinutes,
    showInDiscovery,
    showApproximateDistance,
    showActiveStatus,
    showOccupation,
    reduceMotion,
    boldText,
  );
}
