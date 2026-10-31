import 'package:flutter/foundation.dart';

import 'profile.dart';

/// Who the person wants to see.
enum ShowMe { everyone, women, men }

/// Discovery preferences. Distances are approximate on purpose.
///
/// In this phase the mock repository applies them locally. With a backend the
/// same values would be sent as query parameters and the server would filter.
@immutable
class DiscoveryFilters {
  const DiscoveryFilters({
    this.minAge = minimumAge,
    this.maxAge = maximumAge,
    this.maxDistanceKm,
    this.showMe = ShowMe.everyone,
    this.verifiedOnly = false,
    this.interests = const {},
  });

  /// The app's minimum age (matches the sign-up eligibility rule).
  static const int minimumAge = 18;
  static const int maximumAge = 60;

  /// Distance slider range. At [distanceCeilingKm] the limit means "any".
  static const int minDistanceKm = 5;
  static const int distanceCeilingKm = 100;

  static const DiscoveryFilters defaults = DiscoveryFilters();

  final int minAge;
  final int maxAge;

  /// `null` means any distance.
  final int? maxDistanceKm;
  final ShowMe showMe;
  final bool verifiedOnly;

  /// Show only people who share at least one of these interests.
  final Set<String> interests;

  bool get isDefault => this == defaults;

  /// How many preferences differ from the defaults (shown on the filter icon).
  int get activeCount =>
      (minAge != minimumAge || maxAge != maximumAge ? 1 : 0) +
      (maxDistanceKm != null ? 1 : 0) +
      (showMe != ShowMe.everyone ? 1 : 0) +
      (verifiedOnly ? 1 : 0) +
      (interests.isNotEmpty ? 1 : 0);

  bool matches(Profile profile) {
    if (profile.age < minAge || profile.age > maxAge) return false;
    final limit = maxDistanceKm;
    if (limit != null) {
      final distance = profile.distanceKm;
      if (distance == null || distance > limit) return false;
    }
    switch (showMe) {
      case ShowMe.everyone:
        break;
      case ShowMe.women:
        if (profile.gender != ProfileGender.female) return false;
      case ShowMe.men:
        if (profile.gender != ProfileGender.male) return false;
    }
    if (verifiedOnly && !profile.isVerified) return false;
    if (interests.isNotEmpty && !profile.interests.any(interests.contains)) {
      return false;
    }
    return true;
  }

  DiscoveryFilters copyWith({
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    bool clearDistance = false,
    ShowMe? showMe,
    bool? verifiedOnly,
    Set<String>? interests,
  }) => DiscoveryFilters(
    minAge: minAge ?? this.minAge,
    maxAge: maxAge ?? this.maxAge,
    maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
    showMe: showMe ?? this.showMe,
    verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    interests: interests ?? this.interests,
  );

  @override
  bool operator ==(Object other) =>
      other is DiscoveryFilters &&
      other.minAge == minAge &&
      other.maxAge == maxAge &&
      other.maxDistanceKm == maxDistanceKm &&
      other.showMe == showMe &&
      other.verifiedOnly == verifiedOnly &&
      setEquals(other.interests, interests);

  @override
  int get hashCode => Object.hash(
    minAge,
    maxAge,
    maxDistanceKm,
    showMe,
    verifiedOnly,
    Object.hashAllUnordered(interests),
  );
}
