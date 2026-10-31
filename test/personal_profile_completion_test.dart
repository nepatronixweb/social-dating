import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/features/profile/personal_info/personal_profile.dart';
import 'package:social_dating/features/profile/personal_info/personal_profile_completion.dart';
import 'package:social_dating/features/profile/personal_info/personal_profile_options.dart';

void main() {
  group('PersonalProfileCompletion', () {
    test('empty profile is 0%', () {
      const completion = PersonalProfileCompletion(PersonalProfile());
      expect(completion.overallPercent, 0);
      expect(completion.progressLabel, 'Add your details');
    });

    test('weights sum to 100', () {
      final sum = PersonalProfileSection.values.fold<int>(
        0,
        (total, section) => total + section.weight,
      );
      expect(sum, 100);
    });

    test('filled basic section contributes its weight', () {
      final profile = PersonalProfile(
        fullName: 'Avery Sample',
        birthDate: DateTime(1995, 4, 12),
        gender: 'female',
        interestedIn: 'men',
        photoCount: 3,
        city: 'Kathmandu',
      );
      final completion = PersonalProfileCompletion(profile);
      expect(completion.sectionPercent(PersonalProfileSection.basic), 100);
      expect(completion.overallPercent, PersonalProfileSection.basic.weight);
      expect(completion.progressLabel, 'Keep going');
    });

    test('personality requires interests and prompts', () {
      final profile = PersonalProfile(
        interests: PersonalProfileOptions.interests.take(3).toList(),
        personality: 'ambivert',
        loveLanguage: 'quality_time',
        prompts: [
          for (final choice in PersonalProfileOptions.promptChoices.take(3))
            ProfilePromptAnswer(promptKey: choice.id, answer: 'Sample'),
        ],
      );
      final completion = PersonalProfileCompletion(profile);
      expect(
        completion.sectionPercent(PersonalProfileSection.personality),
        100,
      );
    });
  });
}
