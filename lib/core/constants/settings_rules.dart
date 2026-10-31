/// Notification, privacy, safety and account rules for this frontend-only
/// build. Nothing here talks to a push service, moderator queue or retention
/// backend.
abstract final class SettingsRules {
  static const String mockLabel = 'Mock';

  static const String preferencesDisclosure =
      'These choices are saved on this device.';

  static const String quietHoursNote =
      'Quiet hours are stored as a preference.';

  static const String reminderNote =
      'A profile-completion reminder can be set every 3–5 days.';

  static const String reportDisclosure =
      'Submitting records a mock report on this device. It is not sent to '
      'moderators.';

  static const String reportSubmittedTitle = 'Report saved';

  static const String reportSubmittedBody =
      'We received your report. You can return to Safety at any time.';

  static const String deletionDisclosure =
      'Requesting deletion ends this session. Some records may be kept under '
      'the retention policy.';

  static const String changePhoneNotice =
      'No SMS is sent. Only a masked number is shown after you save. The '
      'full number stays in memory on this device and is not persisted.';

  static const List<int> reminderDayOptions = [3, 4, 5];
  static const int defaultReminderDays = 4;
  static const int defaultQuietStartMinutes = 22 * 60;
  static const int defaultQuietEndMinutes = 7 * 60;

  static const List<String> reportCategories = [
    'Fake profile',
    'Inappropriate photos',
    'Harassment',
    'Scam or spam',
    'Underage',
    'Something else',
  ];

  static const List<(String, String)> publicFields = [
    ('Name', 'Shown on your profile card.'),
    ('Age', 'Shown next to your name.'),
    ('City', 'City-level only. Exact location stays private.'),
    ('Photos', 'The photos you add to your profile.'),
    ('Bio and interests', 'What you write about yourself.'),
    ('Occupation', 'Optional. You can hide it below.'),
  ];

  static const List<(String, String)> privateFields = [
    (
      'Phone number',
      'Used to sign in. Only a masked label is shown in the app.',
    ),
    ('Exact location', 'Never shown. Distance is approximate.'),
    (
      'Date of birth',
      'Used once for age eligibility, then discarded from this device.',
    ),
  ];

  static const List<(String, String)> deletionConsequences = [
    (
      'Your profile may leave discovery',
      'Other people would stop seeing your card, subject to a future backend '
          'retention policy.',
    ),
    (
      'Matches and messages may be removed',
      'Conversations tied to this account may no longer appear.',
    ),
    (
      'Some records may be kept',
      'Safety, billing or legal records may be retained for a limited time '
          'under the retention policy.',
    ),
    (
      'This session will end',
      'You will need to sign in again if you return.',
    ),
  ];

  /// `22:00` from minutes past midnight.
  static String formatClock(int minutes) {
    final wrapped = minutes % (24 * 60);
    final hours = wrapped ~/ 60;
    final mins = wrapped % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }

  static String quietHoursLabel(int startMinutes, int endMinutes) =>
      '${formatClock(startMinutes)}–${formatClock(endMinutes)}';
}
