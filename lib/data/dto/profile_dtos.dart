import 'package:flutter/foundation.dart';

import '../../core/errors/api_error_mapper.dart';
import '../models/discovery_filters.dart';
import '../models/profile.dart';
import '../models/swipe.dart';
import 'json_codec.dart';
import 'typed_values.dart';

/// Public profile as proposed for the wire. Photo URLs are strings supplied by
/// the backend; this client never invents hosts. Private phone / geo fields
/// are rejected.
@immutable
class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.displayName,
    required this.age,
    required this.city,
    this.bio = '',
    this.interests = const [],
    this.isVerified = false,
    this.isOnline = false,
    this.photoCount = 0,
    this.distanceKm,
    this.occupation,
    this.gender,
    this.lookingFor,
    this.photoUrls = const [],
  });

  final ProfileId id;
  final String displayName;
  final int age;
  final String city;
  final String bio;
  final List<String> interests;
  final bool isVerified;
  final bool isOnline;
  final int photoCount;
  final int? distanceKm;
  final String? occupation;
  final ProfileGender? gender;
  final String? lookingFor;
  final List<String> photoUrls;

  factory ProfileDto.fromJson(Object? json) =>
      ProfileDto.fromMap(JsonMap.from(json));

  factory ProfileDto.fromMap(JsonMap map) {
    map.rejectPrivateFields(const [
      'phone',
      'e164',
      'birthDate',
      'dateOfBirth',
      'latitude',
      'longitude',
      'exactLocation',
    ]);
    return ProfileDto(
      id: readProfileId(map),
      displayName: map.string('displayName'),
      age: map.integer('age'),
      city: map.string('city'),
      bio: map.optionalString('bio', allowEmpty: true) ?? '',
      interests: map.contains('interests')
          ? map.stringList('interests')
          : const [],
      isVerified: map.optionalBoolean('isVerified') ?? false,
      isOnline: map.optionalBoolean('isOnline') ?? false,
      photoCount: map.optionalInteger('photoCount') ?? 0,
      distanceKm: map.optionalInteger('distanceKm'),
      occupation: map.optionalString('occupation'),
      gender: () {
        final raw = map.optionalString('gender');
        if (raw == null) return null;
        final parsed = parseProfileGender(raw);
        if (parsed == null) {
          throw JsonFormatException(
            'Unknown ProfileGender "$raw" at ${map.path}.gender.',
          );
        }
        return parsed;
      }(),
      lookingFor: map.optionalString('lookingFor'),
      photoUrls: map.contains('photoUrls')
          ? map.stringList('photoUrls')
          : const [],
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'displayName': displayName,
    'age': age,
    'city': city,
    'bio': bio,
    'interests': interests,
    'isVerified': isVerified,
    'isOnline': isOnline,
    'photoCount': photoCount,
    'distanceKm': distanceKm,
    'occupation': occupation,
    'gender': gender?.name,
    'lookingFor': lookingFor,
    'photoUrls': photoUrls,
  };

  Profile toDomain() => Profile(
    id: id.raw,
    displayName: displayName,
    age: age,
    city: city,
    bio: bio,
    interests: interests,
    isVerified: isVerified,
    isOnline: isOnline,
    photoCount: photoCount > 0
        ? photoCount
        : (photoUrls.isEmpty ? 3 : photoUrls.length),
    distanceKm: distanceKm,
    occupation: occupation,
    gender: gender,
    lookingFor: lookingFor,
    photoUrls: photoUrls,
  );
}

@immutable
class DiscoveryCandidateDto {
  const DiscoveryCandidateDto({required this.profile});

  final ProfileDto profile;

  factory DiscoveryCandidateDto.fromJson(Object? json) =>
      DiscoveryCandidateDto.fromMap(JsonMap.from(json));

  factory DiscoveryCandidateDto.fromMap(JsonMap map) {
    final nested = map.optionalObject('profile');
    return DiscoveryCandidateDto(
      profile: nested == null
          ? ProfileDto.fromMap(map)
          : ProfileDto.fromMap(nested),
    );
  }

  Map<String, Object?> toJson() => profile.toJson();

  Profile toDomain() => profile.toDomain();
}

@immutable
class DiscoveryFiltersDto {
  const DiscoveryFiltersDto({required this.filters});

  final DiscoveryFilters filters;

  factory DiscoveryFiltersDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return DiscoveryFiltersDto(
      filters: DiscoveryFilters(
        minAge: map.optionalInteger('minAge') ?? DiscoveryFilters.minimumAge,
        maxAge: map.optionalInteger('maxAge') ?? DiscoveryFilters.maximumAge,
        maxDistanceKm: map.optionalInteger('maxDistanceKm'),
        showMe: map.optionalEnum('showMe', ShowMe.values) ?? ShowMe.everyone,
        verifiedOnly: map.optionalBoolean('verifiedOnly') ?? false,
        interests: map.contains('interests')
            ? map.stringList('interests').toSet()
            : const {},
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'minAge': filters.minAge,
    'maxAge': filters.maxAge,
    'maxDistanceKm': filters.maxDistanceKm,
    'showMe': filters.showMe.name,
    'verifiedOnly': filters.verifiedOnly,
    'interests': filters.interests.toList()..sort(),
  };
}

@immutable
class SwipeRequestDto {
  const SwipeRequestDto({
    required this.profileId,
    required this.direction,
    required this.confirmedPaid,
  });

  final ProfileId profileId;
  final SwipeDirection direction;
  final bool confirmedPaid;

  factory SwipeRequestDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return SwipeRequestDto(
      profileId: readProfileId(map, 'profileId'),
      direction: map.enumValue('direction', SwipeDirection.values),
      confirmedPaid: map.boolean('confirmedPaid'),
    );
  }

  Map<String, Object?> toJson() => {
    'profileId': profileId.raw,
    'direction': direction.name,
    'confirmedPaid': confirmedPaid,
  };
}

@immutable
class SwipeQuotaDto {
  const SwipeQuotaDto({
    required this.profileComplete,
    required this.previewUsed,
    required this.dailyUsed,
    required this.freeDailyLimit,
    required this.balancePaisa,
    required this.pricePaisa,
    required this.dayKey,
    required this.resetsAt,
  });

  final bool profileComplete;
  final int previewUsed;
  final int dailyUsed;
  final int? freeDailyLimit;
  final Paisa balancePaisa;
  final Paisa pricePaisa;
  final String dayKey;
  final DateTime resetsAt;

  factory SwipeQuotaDto.fromJson(Object? json) =>
      SwipeQuotaDto.fromMap(JsonMap.from(json));

  factory SwipeQuotaDto.fromMap(JsonMap map) => SwipeQuotaDto(
    profileComplete: map.boolean('profileComplete'),
    previewUsed: map.integer('previewUsed'),
    dailyUsed: map.integer('dailyUsed'),
    freeDailyLimit: map.optionalInteger('freeDailyLimit'),
    balancePaisa: Paisa.read(map, 'balancePaisa'),
    pricePaisa: Paisa.read(map, 'pricePaisa'),
    dayKey: map.string('dayKey'),
    resetsAt: map.dateTime('resetsAt'),
  );

  Map<String, Object?> toJson() => {
    'profileComplete': profileComplete,
    'previewUsed': previewUsed,
    'dailyUsed': dailyUsed,
    'freeDailyLimit': freeDailyLimit,
    'balancePaisa': balancePaisa.toJson(),
    'pricePaisa': pricePaisa.toJson(),
    'dayKey': dayKey,
    'resetsAt': resetsAt.toUtc().toIso8601String(),
  };

  SwipeQuota toDomain() => SwipeQuota(
    profileComplete: profileComplete,
    previewUsed: previewUsed,
    dailyUsed: dailyUsed,
    freeDailyLimit: freeDailyLimit,
    balancePaisa: balancePaisa.paisa,
    pricePaisa: pricePaisa.paisa,
    dayKey: dayKey,
    resetsAt: resetsAt,
  );
}

@immutable
class SwipeOutcomeDto {
  const SwipeOutcomeDto({
    required this.quota,
    this.matchedProfile,
    this.chargedPaisa = const Paisa(0),
    this.rejection,
  });

  final SwipeQuotaDto quota;
  final ProfileDto? matchedProfile;
  final Paisa chargedPaisa;
  final SwipeRejection? rejection;

  factory SwipeOutcomeDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final matched = map.optionalObject('matchedProfile');
    return SwipeOutcomeDto(
      quota: SwipeQuotaDto.fromMap(map.object('quota')),
      matchedProfile: matched == null ? null : ProfileDto.fromMap(matched),
      chargedPaisa: Paisa.readOptional(map, 'chargedPaisa'),
      rejection: map.optionalEnum('rejection', SwipeRejection.values),
    );
  }

  Map<String, Object?> toJson() => {
    'quota': quota.toJson(),
    'matchedProfile': matchedProfile?.toJson(),
    'chargedPaisa': chargedPaisa.toJson(),
    'rejection': rejection?.name,
  };

  SwipeOutcome toDomain() {
    final quotaDomain = quota.toDomain();
    final rejected = rejection;
    if (rejected != null) {
      return SwipeOutcome.rejected(quota: quotaDomain, rejection: rejected);
    }
    return SwipeOutcome.recorded(
      quota: quotaDomain,
      matchedProfile: matchedProfile?.toDomain(),
      chargedPaisa: chargedPaisa.paisa,
    );
  }
}

@immutable
class UndoOutcomeDto {
  const UndoOutcomeDto({required this.profile, required this.quota});

  final ProfileDto profile;
  final SwipeQuotaDto quota;

  factory UndoOutcomeDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return UndoOutcomeDto(
      profile: ProfileDto.fromMap(map.object('profile')),
      quota: SwipeQuotaDto.fromMap(map.object('quota')),
    );
  }

  UndoOutcome toDomain() =>
      UndoOutcome(profile: profile.toDomain(), quota: quota.toDomain());
}
