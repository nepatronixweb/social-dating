// ============================================================================
// MOCK DATA ONLY: device preferences, reports and deletion requests
//
// Preferences are stored in SharedPreferences on this device. Reports and
// deletion requests live in memory. NOTHING is sent to moderators, a push
// service, or a retention backend. Nothing outside `mock_*` files and the
// approved seam may import this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/errors/app_failure.dart';
import '../models/safety_report.dart';
import '../models/user_preferences.dart';
import '../services/local_preferences_service.dart';
import 'mock_profile_repository.dart';
import 'settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository({
    required LocalPreferencesService preferences,
    MockScenario Function()? scenario,
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? now,
  }) : _preferences = preferences,
       _scenario = scenario ?? (() => MockScenario.populated),
       _now = now ?? DateTime.now;

  final LocalPreferencesService _preferences;
  final MockScenario Function() _scenario;
  final Duration latency;
  final DateTime Function() _now;

  SafetyReport? _lastReport;
  int _reportCounter = 0;
  bool deletionRequested = false;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  Future<T> _change<T>(Future<T> Function() change) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    return change();
  }

  @override
  Future<UserPreferences> fetchPreferences() =>
      _fetch(() => _preferences.userPreferences, const UserPreferences());

  @override
  Future<UserPreferences> savePreferences(UserPreferences preferences) =>
      _change(() async {
        await _preferences.setUserPreferences(preferences);
        return preferences;
      });

  @override
  Future<SafetyReport> submitReport({
    required String category,
    String details = '',
    String? attachmentAsset,
    String? subjectName,
    String? reportedAccountId,
  }) => _change(() async {
    final report = SafetyReport(
      id: 'mock-report-${++_reportCounter}',
      category: category,
      details: details.trim(),
      attachmentAsset: attachmentAsset,
      subjectName: subjectName,
      reportedAccountId: reportedAccountId,
      createdAt: _now(),
    );
    _lastReport = report;
    return report;
  });

  @override
  Future<SafetyReport?> lastReport() => _fetch(() => _lastReport, null);

  @override
  Future<void> requestAccountDeletion() => _change(() async {
    deletionRequested = true;
  });
}
