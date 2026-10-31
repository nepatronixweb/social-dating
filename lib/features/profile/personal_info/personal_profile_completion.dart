import 'personal_profile.dart';
import 'personal_profile_options.dart';

enum PersonalProfileSection {
  basic,
  appearance,
  lifestyle,
  education,
  dating,
  personality,
}

extension PersonalProfileSectionX on PersonalProfileSection {
  String get title => switch (this) {
    PersonalProfileSection.basic => 'Basic information',
    PersonalProfileSection.appearance => 'Photos and appearance',
    PersonalProfileSection.lifestyle => 'Lifestyle',
    PersonalProfileSection.education => 'Education and profession',
    PersonalProfileSection.dating => 'Dating preferences',
    PersonalProfileSection.personality => 'Interests and personality',
  };

  /// Contribution toward overall completion (sums to 100).
  int get weight => switch (this) {
    PersonalProfileSection.basic => 25,
    PersonalProfileSection.appearance => 20,
    PersonalProfileSection.lifestyle => 15,
    PersonalProfileSection.education => 10,
    PersonalProfileSection.dating => 15,
    PersonalProfileSection.personality => 15,
  };
}

class PersonalProfileCompletion {
  const PersonalProfileCompletion(this.profile);

  final PersonalProfile profile;

  int sectionPercent(PersonalProfileSection section) {
    final filled = _filledCount(section);
    final total = _fieldCount(section);
    if (total == 0) return 0;
    return ((filled / total) * 100).round().clamp(0, 100);
  }

  int get overallPercent {
    var score = 0.0;
    for (final section in PersonalProfileSection.values) {
      score += section.weight * (sectionPercent(section) / 100);
    }
    return score.round().clamp(0, 100);
  }

  String get progressLabel {
    final percent = overallPercent;
    if (percent >= 100) return 'Profile complete';
    if (percent >= 70) return 'Almost there';
    if (percent >= 40) return 'Good progress';
    if (percent > 0) return 'Keep going';
    return 'Add your details';
  }

  bool get isComplete => overallPercent >= 100;

  int _fieldCount(PersonalProfileSection section) => switch (section) {
    PersonalProfileSection.basic => 6,
    PersonalProfileSection.appearance => 5,
    PersonalProfileSection.lifestyle => 7,
    PersonalProfileSection.education => 4,
    PersonalProfileSection.dating => 7,
    PersonalProfileSection.personality => 4,
  };

  int _filledCount(PersonalProfileSection section) {
    final p = profile;
    switch (section) {
      case PersonalProfileSection.basic:
        return [
          _has(p.fullName),
          p.birthDate != null,
          _has(p.gender),
          _has(p.interestedIn),
          p.photoCount >= 2,
          _has(p.city),
        ].where((v) => v).length;
      case PersonalProfileSection.appearance:
        return [
          p.heightCm != null,
          _has(p.bodyType),
          _has(p.hairColor),
          _has(p.eyeColor),
          _has(p.fitnessLifestyle),
        ].where((v) => v).length;
      case PersonalProfileSection.lifestyle:
        return [
          _has(p.drink),
          _has(p.smoke),
          _has(p.exercise),
          _has(p.foodPreference),
          _has(p.pets),
          _has(p.sleepSchedule),
          _has(p.socialLifestyle),
        ].where((v) => v).length;
      case PersonalProfileSection.education:
        return [
          _has(p.educationLevel),
          _has(p.college),
          _has(p.profession),
          p.languages.isNotEmpty,
        ].where((v) => v).length;
      case PersonalProfileSection.dating:
        return [
          _has(p.lookingFor),
          p.preferredAgeMin != null &&
              p.preferredAgeMax != null &&
              p.preferredAgeMin! >= 18 &&
              p.preferredAgeMax! <= 100 &&
              p.preferredAgeMin! <= p.preferredAgeMax!,
          p.preferredDistanceKm != null,
          _has(p.preferredLocation),
          _has(p.childrenPreference),
          _has(p.relationshipStatus),
          _has(p.meetFrequency),
        ].where((v) => v).length;
      case PersonalProfileSection.personality:
        return [
          p.interests.length >= PersonalProfileOptions.minInterests,
          _has(p.personality),
          _has(p.loveLanguage),
          p.prompts
                  .where((a) => a.promptKey.isNotEmpty && a.answer.trim().isNotEmpty)
                  .length >=
              PersonalProfileOptions.promptSlots,
        ].where((v) => v).length;
    }
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}
