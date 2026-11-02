import 'package:flutter/foundation.dart';

import '../models/account_state.dart';
import 'json_codec.dart';
import 'typed_values.dart';

/// Request to start phone verification. Confirmed by `backend/CONTRACT.md`.
@immutable
class RequestCodeRequestDto {
  const RequestCodeRequestDto({required this.e164Phone});

  final String e164Phone;

  Map<String, Object?> toJson() => {'phone': e164Phone};

  factory RequestCodeRequestDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return RequestCodeRequestDto(e164Phone: map.string('phone'));
  }
}

@immutable
class RequestCodeResponseDto {
  const RequestCodeResponseDto({
    this.retryAfterSeconds = 30,
    this.registered = false,
  });

  final int retryAfterSeconds;
  final bool registered;

  factory RequestCodeResponseDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return RequestCodeResponseDto(
      retryAfterSeconds: map.optionalInteger('retryAfterSeconds') ?? 30,
      registered: map.optionalBoolean('registered') ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'retryAfterSeconds': retryAfterSeconds,
    'registered': registered,
  };
}

/// Onboarding flags. Must not include a phone number or birth date.
@immutable
class AccountStateDto {
  const AccountStateDto({
    required this.id,
    this.termsAccepted = false,
    this.isAgeEligible,
    this.displayName,
    this.gender,
    this.restrictionStatus,
  });

  final AccountId id;
  final bool termsAccepted;
  final bool? isAgeEligible;
  final String? displayName;
  final String? gender;
  final String? restrictionStatus;

  factory AccountStateDto.fromJson(Object? json) =>
      AccountStateDto.fromMap(JsonMap.from(json));

  factory AccountStateDto.fromMap(JsonMap map) {
    map.rejectPrivateFields(const [
      'phone',
      'e164',
      'birthDate',
      'dateOfBirth',
    ]);
    return AccountStateDto(
      id: readAccountId(map),
      termsAccepted: map.optionalBoolean('termsAccepted') ?? false,
      isAgeEligible: map.optionalBoolean('isAgeEligible'),
      displayName: map.optionalString('displayName'),
      gender: map.optionalString('gender'),
      restrictionStatus: map.optionalString('restrictionStatus'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'termsAccepted': termsAccepted,
    'isAgeEligible': isAgeEligible,
    'displayName': displayName,
    'gender': gender,
    'restrictionStatus': restrictionStatus,
  };

  AccountState toDomain() => AccountState(
    id: id.raw,
    termsAccepted: termsAccepted,
    isAgeEligible: isAgeEligible,
    displayName: displayName,
    gender: gender,
    restrictionStatus: restrictionStatus,
  );

  factory AccountStateDto.fromDomain(AccountState state) => AccountStateDto(
    id: AccountId(state.id),
    termsAccepted: state.termsAccepted,
    isAgeEligible: state.isAgeEligible,
    displayName: state.displayName,
    gender: state.gender,
    restrictionStatus: state.restrictionStatus,
  );
}

/// Verify-code / refresh response. Tokens belong in secure storage, never in
/// logs or SharedPreferences. [toJson] omits secrets unless asked.
@immutable
class AuthVerifyResponseDto {
  const AuthVerifyResponseDto({
    required this.account,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AccountStateDto account;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  factory AuthVerifyResponseDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return AuthVerifyResponseDto(
      account: AccountStateDto.fromMap(map.object('account')),
      accessToken: map.optionalString('accessToken'),
      refreshToken: map.optionalString('refreshToken'),
      expiresAt: map.optionalDateTime('expiresAt'),
    );
  }

  Map<String, Object?> toJson({bool includeSecrets = false}) => {
    'account': account.toJson(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    if (includeSecrets) 'accessToken': accessToken,
    if (includeSecrets) 'refreshToken': refreshToken,
  };

  @override
  String toString() =>
      'AuthVerifyResponseDto(account: ${account.id.raw}, hasAccessToken: '
      '${accessToken != null}, hasRefreshToken: ${refreshToken != null})';
}

@immutable
class RefreshRequestDto {
  const RefreshRequestDto({required this.refreshToken});

  final String refreshToken;

  Map<String, Object?> toJson() => {'refreshToken': refreshToken};
}

/// Calendar date only (`YYYY-MM-DD`). The server stores it privately and never
/// returns it.
@immutable
class SubmitAgeRequestDto {
  const SubmitAgeRequestDto({required this.birthDate});

  final DateTime birthDate;

  Map<String, Object?> toJson() {
    final year = birthDate.year.toString().padLeft(4, '0');
    final month = birthDate.month.toString().padLeft(2, '0');
    final day = birthDate.day.toString().padLeft(2, '0');
    return {'birthDate': '$year-$month-$day'};
  }
}

@immutable
class SetGenderRequestDto {
  const SetGenderRequestDto({required this.gender});

  final String gender;

  Map<String, Object?> toJson() => {'gender': gender};
}

@immutable
class CompleteProfileRequestDto {
  const CompleteProfileRequestDto({
    required this.displayName,
    this.bio = '',
    this.interests = const [],
    this.city,
    this.gender,
  });

  final String displayName;
  final String bio;
  final List<String> interests;
  final String? city;
  final String? gender;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'bio': bio,
    'interests': interests,
    if (city != null) 'city': city,
    if (gender != null) 'gender': gender,
  };
}
