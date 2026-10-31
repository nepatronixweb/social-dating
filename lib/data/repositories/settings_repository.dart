import '../models/safety_report.dart';
import '../models/user_preferences.dart';

/// Device preferences, mock reports and mock deletion requests.
///
/// Implementations in this build persist preferences on the device only and
/// never contact a backend, push service or moderator queue.
abstract interface class SettingsRepository {
  Future<UserPreferences> fetchPreferences();

  Future<UserPreferences> savePreferences(UserPreferences preferences);

  /// Records a mock report on this device. Does not notify moderators.
  Future<SafetyReport> submitReport({
    required String category,
    String details,
    String? attachmentAsset,
    String? subjectName,
  });

  Future<SafetyReport?> lastReport();

  /// Records that a deletion was requested in this mock. Ending the session
  /// is the session notifier's job.
  Future<void> requestAccountDeletion();
}
