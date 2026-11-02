import 'package:flutter/foundation.dart';

/// What the server knows about an account's onboarding progress.
///
/// Deliberately holds no phone number and no birth date: the app only needs to
/// know the outcomes (terms accepted, age eligible, gender, name chosen).
@immutable
class AccountState {
  const AccountState({
    required this.id,
    this.termsAccepted = false,
    this.isAgeEligible,
    this.displayName,
    this.gender,
    this.restrictionStatus,
  });

  final String id;
  final bool termsAccepted;

  /// `null` until a birth date has been submitted.
  final bool? isAgeEligible;
  final String? displayName;

  /// Wire name: male, female, lgbtq, other.
  final String? gender;

  /// `null` when unrestricted; else suspended, shadowBanned, or banned.
  final String? restrictionStatus;

  bool get hasBirthDate => isAgeEligible != null;

  bool get isRestricted =>
      restrictionStatus != null && restrictionStatus!.isNotEmpty;

  AccountState copyWith({
    bool? termsAccepted,
    bool? isAgeEligible,
    String? displayName,
    String? gender,
    String? restrictionStatus,
  }) => AccountState(
    id: id,
    termsAccepted: termsAccepted ?? this.termsAccepted,
    isAgeEligible: isAgeEligible ?? this.isAgeEligible,
    displayName: displayName ?? this.displayName,
    gender: gender ?? this.gender,
    restrictionStatus: restrictionStatus ?? this.restrictionStatus,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'termsAccepted': termsAccepted,
    'isAgeEligible': isAgeEligible,
    'displayName': displayName,
    'gender': gender,
    'restrictionStatus': restrictionStatus,
  };

  static AccountState? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    return AccountState(
      id: id,
      termsAccepted: json['termsAccepted'] == true,
      isAgeEligible: json['isAgeEligible'] is bool
          ? json['isAgeEligible'] as bool
          : null,
      displayName: json['displayName'] is String
          ? json['displayName'] as String
          : null,
      gender: json['gender'] is String ? json['gender'] as String : null,
      restrictionStatus: json['restrictionStatus'] is String
          ? json['restrictionStatus'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountState &&
      other.id == id &&
      other.termsAccepted == termsAccepted &&
      other.isAgeEligible == isAgeEligible &&
      other.displayName == displayName &&
      other.gender == gender &&
      other.restrictionStatus == restrictionStatus;

  @override
  int get hashCode => Object.hash(
    id,
    termsAccepted,
    isAgeEligible,
    displayName,
    gender,
    restrictionStatus,
  );
}
