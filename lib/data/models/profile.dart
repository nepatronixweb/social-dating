import 'package:flutter/foundation.dart';

/// Gender chosen during account setup and shown on a profile.
enum ProfileGender { male, female, lgbtq, other }

extension ProfileGenderLabel on ProfileGender {
  String get label => switch (this) {
    ProfileGender.male => 'Male',
    ProfileGender.female => 'Female',
    ProfileGender.lgbtq => 'LGBTQ+',
    ProfileGender.other => 'Other',
  };

  /// Extra daily swipes and paid chat words apply to male accounts.
  bool get paysForExtraSwipesAndWords => this == ProfileGender.male;

  /// Mock withdrawals and daily match preference. Not male accounts.
  bool get canWithdrawAndSetDailyPreference => this != ProfileGender.male;

  /// Female, LGBTQ+ and other accounts have every Premium feature at no charge.
  bool get hasComplimentaryPremium => this != ProfileGender.male;

  /// Only male accounts buy a subscription for Premium.
  bool get needsPaidSubscription => this == ProfileGender.male;

  /// Who this account sees in discovery.
  ///
  /// Male accounts see female and LGBTQ+ (including stored `transgender`).
  /// Female, LGBTQ+ and other accounts see male.
  bool sees(ProfileGender? candidate) {
    if (candidate == null) return false;
    return switch (this) {
      ProfileGender.male =>
        candidate == ProfileGender.female || candidate == ProfileGender.lgbtq,
      ProfileGender.female ||
      ProfileGender.lgbtq ||
      ProfileGender.other => candidate == ProfileGender.male,
    };
  }
}

/// Accepts current wire names and earlier `woman` / `man` / `nonBinary` /
/// `transgender` values still stored on some accounts.
ProfileGender? parseProfileGender(String? raw) {
  return switch (raw) {
    'male' || 'man' => ProfileGender.male,
    'female' || 'woman' => ProfileGender.female,
    'lgbtq' || 'nonBinary' || 'transgender' => ProfileGender.lgbtq,
    'other' => ProfileGender.other,
    _ => null,
  };
}

/// Minimal profile shape used by shared UI. This is the app-level model, not a
/// wire format; mapping from API DTOs will live in the data layer later.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.age,
    required this.city,
    this.bio = '',
    this.interests = const [],
    this.isVerified = false,
    this.isOnline = false,
    this.photoCount = 3,
    this.distanceKm,
    this.occupation,
    this.gender,
    this.lookingFor,
    this.photoAssets = const [],
    this.photoUrls = const [],
    this.spendablePoints,
  });

  final String id;
  final String displayName;
  final int age;
  final String city;
  final String bio;
  final List<String> interests;
  final bool isVerified;
  final bool isOnline;

  /// Number of photos available (rendered as placeholders in Phase 1).
  final int photoCount;
  final int? distanceKm;
  final String? occupation;
  final ProfileGender? gender;

  /// What the person says they are looking for (free text).
  final String? lookingFor;

  /// Local sample photos for this frontend-only build. Empty means the
  /// placeholder wash is shown. A real backend would send image URLs instead.
  final List<String> photoAssets;

  /// Signed media paths from the API. Mock profiles leave this empty and use
  /// [photoAssets] instead.
  final List<String> photoUrls;

  /// Male wallet balance disclosed to female / LGBTQ+ / other viewers only.
  final int? spendablePoints;

  /// Photos to draw, preferring API URLs then mock assets.
  List<String> get photos => photoUrls.isNotEmpty ? photoUrls : photoAssets;

  /// Stable index used to pick a placeholder photo wash for this person.
  int get photoSeed => id.codeUnits.fold(0, (sum, unit) => sum + unit) % 6;

  Profile copyWith({
    ProfileGender? gender,
    int? spendablePoints,
    bool clearSpendablePoints = false,
  }) => Profile(
    id: id,
    displayName: displayName,
    age: age,
    city: city,
    bio: bio,
    interests: interests,
    isVerified: isVerified,
    isOnline: isOnline,
    photoCount: photoCount,
    distanceKm: distanceKm,
    occupation: occupation,
    gender: gender ?? this.gender,
    lookingFor: lookingFor,
    photoAssets: photoAssets,
    photoUrls: photoUrls,
    spendablePoints: clearSpendablePoints
        ? null
        : (spendablePoints ?? this.spendablePoints),
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.age == age &&
      other.city == city &&
      other.bio == bio &&
      listEquals(other.interests, interests) &&
      other.isVerified == isVerified &&
      other.isOnline == isOnline &&
      other.photoCount == photoCount &&
      other.distanceKm == distanceKm &&
      other.occupation == occupation &&
      other.gender == gender &&
      other.lookingFor == lookingFor &&
      listEquals(other.photoAssets, photoAssets) &&
      listEquals(other.photoUrls, photoUrls) &&
      other.spendablePoints == spendablePoints;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    age,
    city,
    bio,
    Object.hashAll(interests),
    isVerified,
    isOnline,
    photoCount,
    distanceKm,
    occupation,
    gender,
    lookingFor,
    Object.hashAll(photoAssets),
    Object.hashAll(photoUrls),
    spendablePoints,
  );
}
