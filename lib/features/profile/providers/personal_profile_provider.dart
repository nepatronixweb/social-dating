import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import '../../../data/services/service_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../personal_info/personal_profile.dart';
import '../personal_info/personal_profile_completion.dart';
import 'photo_providers.dart';

/// Maps account gender onto the Personal Information option ids.
String? personalGenderFromSession(ProfileGender? gender) => switch (gender) {
  ProfileGender.male => 'male',
  ProfileGender.female => 'female',
  ProfileGender.lgbtq => 'non_binary',
  ProfileGender.other => 'self_describe',
  null => null,
};

class PersonalProfileNotifier extends Notifier<PersonalProfile> {
  @override
  PersonalProfile build() {
    final stored = PersonalProfile.decode(
      ref.watch(localPreferencesServiceProvider).personalProfileJson,
    );
    final session = ref.watch(sessionProvider);
    return stored.copyWith(
      fullName: stored.fullName ?? session.displayName,
      phoneLabel: session.phoneLabel ?? stored.phoneLabel,
      gender: stored.gender ?? personalGenderFromSession(session.gender),
    );
  }

  Future<void> save(PersonalProfile Function(PersonalProfile current) fn) async {
    final next = fn(state);
    state = next;
    await ref
        .read(localPreferencesServiceProvider)
        .setPersonalProfileJson(next.encode());
  }
}

final personalProfileProvider =
    NotifierProvider<PersonalProfileNotifier, PersonalProfile>(
      PersonalProfileNotifier.new,
    );

/// Profile merged with live photo count for completion and summaries.
final personalProfileViewProvider = Provider<PersonalProfile>((ref) {
  final profile = ref.watch(personalProfileProvider);
  final photos = ref.watch(myPhotosProvider).asData?.value;
  if (photos == null) return profile;
  return profile.copyWith(photoCount: photos.length);
});

final personalProfileCompletionProvider = Provider<PersonalProfileCompletion>((
  ref,
) {
  return PersonalProfileCompletion(ref.watch(personalProfileViewProvider));
});
