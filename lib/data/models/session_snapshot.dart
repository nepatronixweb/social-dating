import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'account_state.dart';

/// The small amount of session state kept so the UI can resume after an app
/// restart.
///
/// SECURITY: this is not a credential. It holds no token, no phone number and
/// no birth date, only a masked number for display and the onboarding
/// outcomes. A real app restores a session from a token in secure storage and
/// validates it with the backend.
@immutable
class SessionSnapshot {
  const SessionSnapshot({
    required this.statusName,
    required this.savedAt,
    this.phoneLabel,
    this.displayName,
    this.gender,
    this.account,
  });

  /// `AuthStatus.name`, kept as text so this model stays free of feature code.
  final String statusName;
  final DateTime savedAt;
  final String? phoneLabel;
  final String? displayName;

  /// Wire name of the chosen gender (`male`, `female`, `lgbtq`, `other`).
  final String? gender;
  final AccountState? account;

  String encode() => jsonEncode({
    'v': 1,
    'status': statusName,
    'savedAt': savedAt.toIso8601String(),
    'phoneLabel': phoneLabel,
    'displayName': displayName,
    if (gender != null) 'gender': gender,
    'account': account?.toJson(),
  });

  /// Returns `null` for anything missing or malformed, so a corrupt value can
  /// never crash startup.
  static SessionSnapshot? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['v'] != 1) return null;
      final status = json['status'];
      final savedAt = DateTime.tryParse('${json['savedAt']}');
      if (status is! String || savedAt == null) return null;
      return SessionSnapshot(
        statusName: status,
        savedAt: savedAt,
        phoneLabel: json['phoneLabel'] as String?,
        displayName: json['displayName'] as String?,
        gender: json['gender'] is String ? json['gender'] as String : null,
        account: AccountState.fromJson(json['account']),
      );
    } catch (_) {
      return null;
    }
  }
}
