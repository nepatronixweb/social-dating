import 'dart:convert';

import 'personal_profile_options.dart';

/// Full personal-information payload editable from the Profile tab.
class PersonalProfile {
  const PersonalProfile({
    this.fullName,
    this.birthDate,
    this.gender,
    this.interestedIn,
    this.photoCount = 0,
    this.city,
    this.phoneLabel,
    this.heightCm,
    this.bodyType,
    this.hairColor,
    this.eyeColor,
    this.fitnessLifestyle,
    this.drink,
    this.smoke,
    this.exercise,
    this.foodPreference,
    this.pets,
    this.sleepSchedule,
    this.socialLifestyle,
    this.educationLevel,
    this.college,
    this.profession,
    this.company,
    this.jobTitle,
    this.languages = const [],
    this.incomeRange,
    this.lookingFor,
    this.preferredAgeMin,
    this.preferredAgeMax,
    this.preferredDistanceKm,
    this.preferredLocation,
    this.childrenPreference,
    this.relationshipStatus,
    this.meetFrequency,
    this.interests = const [],
    this.personality,
    this.perfectWeekend,
    this.loveLanguage,
    this.communicationStyle,
    this.idealFirstDate,
    this.prompts = const [],
  });

  final String? fullName;
  final DateTime? birthDate;
  final String? gender;
  final String? interestedIn;
  final int photoCount;
  final String? city;
  final String? phoneLabel;

  final int? heightCm;
  final String? bodyType;
  final String? hairColor;
  final String? eyeColor;
  final String? fitnessLifestyle;

  final String? drink;
  final String? smoke;
  final String? exercise;
  final String? foodPreference;
  final String? pets;
  final String? sleepSchedule;
  final String? socialLifestyle;

  final String? educationLevel;
  final String? college;
  final String? profession;
  final String? company;
  final String? jobTitle;
  final List<String> languages;
  final String? incomeRange;

  final String? lookingFor;
  final int? preferredAgeMin;
  final int? preferredAgeMax;
  final int? preferredDistanceKm;
  final String? preferredLocation;
  final String? childrenPreference;
  final String? relationshipStatus;
  final String? meetFrequency;

  final List<String> interests;
  final String? personality;
  final String? perfectWeekend;
  final String? loveLanguage;
  final String? communicationStyle;
  final String? idealFirstDate;

  final List<ProfilePromptAnswer> prompts;

  PersonalProfile copyWith({
    String? fullName,
    DateTime? birthDate,
    String? gender,
    String? interestedIn,
    int? photoCount,
    String? city,
    String? phoneLabel,
    int? heightCm,
    String? bodyType,
    String? hairColor,
    String? eyeColor,
    String? fitnessLifestyle,
    String? drink,
    String? smoke,
    String? exercise,
    String? foodPreference,
    String? pets,
    String? sleepSchedule,
    String? socialLifestyle,
    String? educationLevel,
    String? college,
    String? profession,
    String? company,
    String? jobTitle,
    List<String>? languages,
    String? incomeRange,
    String? lookingFor,
    int? preferredAgeMin,
    int? preferredAgeMax,
    int? preferredDistanceKm,
    String? preferredLocation,
    String? childrenPreference,
    String? relationshipStatus,
    String? meetFrequency,
    List<String>? interests,
    String? personality,
    String? perfectWeekend,
    String? loveLanguage,
    String? communicationStyle,
    String? idealFirstDate,
    List<ProfilePromptAnswer>? prompts,
    bool clearBirthDate = false,
    bool clearHeight = false,
  }) {
    return PersonalProfile(
      fullName: fullName ?? this.fullName,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      photoCount: photoCount ?? this.photoCount,
      city: city ?? this.city,
      phoneLabel: phoneLabel ?? this.phoneLabel,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      bodyType: bodyType ?? this.bodyType,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      fitnessLifestyle: fitnessLifestyle ?? this.fitnessLifestyle,
      drink: drink ?? this.drink,
      smoke: smoke ?? this.smoke,
      exercise: exercise ?? this.exercise,
      foodPreference: foodPreference ?? this.foodPreference,
      pets: pets ?? this.pets,
      sleepSchedule: sleepSchedule ?? this.sleepSchedule,
      socialLifestyle: socialLifestyle ?? this.socialLifestyle,
      educationLevel: educationLevel ?? this.educationLevel,
      college: college ?? this.college,
      profession: profession ?? this.profession,
      company: company ?? this.company,
      jobTitle: jobTitle ?? this.jobTitle,
      languages: languages ?? this.languages,
      incomeRange: incomeRange ?? this.incomeRange,
      lookingFor: lookingFor ?? this.lookingFor,
      preferredAgeMin: preferredAgeMin ?? this.preferredAgeMin,
      preferredAgeMax: preferredAgeMax ?? this.preferredAgeMax,
      preferredDistanceKm: preferredDistanceKm ?? this.preferredDistanceKm,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      childrenPreference: childrenPreference ?? this.childrenPreference,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      meetFrequency: meetFrequency ?? this.meetFrequency,
      interests: interests ?? this.interests,
      personality: personality ?? this.personality,
      perfectWeekend: perfectWeekend ?? this.perfectWeekend,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      idealFirstDate: idealFirstDate ?? this.idealFirstDate,
      prompts: prompts ?? this.prompts,
    );
  }

  Map<String, Object?> toJson() => {
    'fullName': fullName,
    'birthDate': birthDate?.toIso8601String(),
    'gender': gender,
    'interestedIn': interestedIn,
    'photoCount': photoCount,
    'city': city,
    'phoneLabel': phoneLabel,
    'heightCm': heightCm,
    'bodyType': bodyType,
    'hairColor': hairColor,
    'eyeColor': eyeColor,
    'fitnessLifestyle': fitnessLifestyle,
    'drink': drink,
    'smoke': smoke,
    'exercise': exercise,
    'foodPreference': foodPreference,
    'pets': pets,
    'sleepSchedule': sleepSchedule,
    'socialLifestyle': socialLifestyle,
    'educationLevel': educationLevel,
    'college': college,
    'profession': profession,
    'company': company,
    'jobTitle': jobTitle,
    'languages': languages,
    'incomeRange': incomeRange,
    'lookingFor': lookingFor,
    'preferredAgeMin': preferredAgeMin,
    'preferredAgeMax': preferredAgeMax,
    'preferredDistanceKm': preferredDistanceKm,
    'preferredLocation': preferredLocation,
    'childrenPreference': childrenPreference,
    'relationshipStatus': relationshipStatus,
    'meetFrequency': meetFrequency,
    'interests': interests,
    'personality': personality,
    'perfectWeekend': perfectWeekend,
    'loveLanguage': loveLanguage,
    'communicationStyle': communicationStyle,
    'idealFirstDate': idealFirstDate,
    'prompts': [for (final p in prompts) p.toJson()],
  };

  factory PersonalProfile.fromJson(Map<String, Object?> json) {
    DateTime? birth;
    final rawBirth = json['birthDate'];
    if (rawBirth is String && rawBirth.isNotEmpty) {
      birth = DateTime.tryParse(rawBirth);
    }
    return PersonalProfile(
      fullName: json['fullName'] as String?,
      birthDate: birth,
      gender: json['gender'] as String?,
      interestedIn: json['interestedIn'] as String?,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      city: json['city'] as String?,
      phoneLabel: json['phoneLabel'] as String?,
      heightCm: (json['heightCm'] as num?)?.toInt(),
      bodyType: json['bodyType'] as String?,
      hairColor: json['hairColor'] as String?,
      eyeColor: json['eyeColor'] as String?,
      fitnessLifestyle: json['fitnessLifestyle'] as String?,
      drink: json['drink'] as String?,
      smoke: json['smoke'] as String?,
      exercise: json['exercise'] as String?,
      foodPreference: json['foodPreference'] as String?,
      pets: json['pets'] as String?,
      sleepSchedule: json['sleepSchedule'] as String?,
      socialLifestyle: json['socialLifestyle'] as String?,
      educationLevel: json['educationLevel'] as String?,
      college: json['college'] as String?,
      profession: json['profession'] as String?,
      company: json['company'] as String?,
      jobTitle: json['jobTitle'] as String?,
      languages: _stringList(json['languages']),
      incomeRange: json['incomeRange'] as String?,
      lookingFor: json['lookingFor'] as String?,
      preferredAgeMin: (json['preferredAgeMin'] as num?)?.toInt(),
      preferredAgeMax: (json['preferredAgeMax'] as num?)?.toInt(),
      preferredDistanceKm: (json['preferredDistanceKm'] as num?)?.toInt(),
      preferredLocation: json['preferredLocation'] as String?,
      childrenPreference: json['childrenPreference'] as String?,
      relationshipStatus: json['relationshipStatus'] as String?,
      meetFrequency: json['meetFrequency'] as String?,
      interests: _stringList(json['interests']),
      personality: json['personality'] as String?,
      perfectWeekend: json['perfectWeekend'] as String?,
      loveLanguage: json['loveLanguage'] as String?,
      communicationStyle: json['communicationStyle'] as String?,
      idealFirstDate: json['idealFirstDate'] as String?,
      prompts: [
        for (final item in (json['prompts'] as List? ?? const []))
          if (item is Map)
            ProfilePromptAnswer.fromJson(Map<String, Object?>.from(item)),
      ],
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.isNotEmpty) item,
    ];
  }

  String encode() => jsonEncode(toJson());

  static PersonalProfile decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const PersonalProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const PersonalProfile();
      return PersonalProfile.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      return const PersonalProfile();
    }
  }
}

class ProfilePromptAnswer {
  const ProfilePromptAnswer({required this.promptKey, required this.answer});

  final String promptKey;
  final String answer;

  String get promptLabel =>
      PersonalProfileOptions.labelOf(
        PersonalProfileOptions.promptChoices,
        promptKey,
      ) ??
      promptKey;

  Map<String, Object?> toJson() => {'promptKey': promptKey, 'answer': answer};

  factory ProfilePromptAnswer.fromJson(Map<String, Object?> json) =>
      ProfilePromptAnswer(
        promptKey: json['promptKey'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}
