// ============================================================================
// MOCK DATA ONLY: in-memory notification inbox
//
// Items live in memory and vanish when the app restarts. NOTHING is pushed
// to a device, and no reminder is scheduled. Nothing outside `mock_*` files
// and the approved seam may import this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/errors/app_failure.dart';
import '../models/app_notification.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({
    MockScenario Function()? scenario,
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _scenario = scenario ?? (() => MockScenario.populated),
       _now = now ?? DateTime.now {
    reset();
  }

  final MockScenario Function() _scenario;
  final Duration latency;
  final DateTime Function() _now;

  final List<AppNotification> _items = [];

  void reset() {
    final now = _now();
    DateTime ago(Duration d) => now.subtract(d);
    _items
      ..clear()
      ..addAll([
        AppNotification(
          id: 'mock-n-1',
          type: NotificationType.match,
          title: 'New match',
          body: 'You and Morgan Fake liked each other.',
          createdAt: ago(const Duration(hours: 2)),
        ),
        AppNotification(
          id: 'mock-n-2',
          type: NotificationType.message,
          title: 'New message',
          body: 'Avery Sample sent you a message.',
          createdAt: ago(const Duration(minutes: 12)),
        ),
        AppNotification(
          id: 'mock-n-3',
          type: NotificationType.like,
          title: 'Someone likes you',
          body: 'Taylor Dummy liked your profile.',
          createdAt: ago(const Duration(days: 1)),
          isRead: true,
        ),
        AppNotification(
          id: 'mock-n-4',
          type: NotificationType.system,
          title: 'Complete your profile',
          body:
              'A reminder you can set for every 3–5 days.',
          createdAt: ago(const Duration(days: 4)),
        ),
        AppNotification(
          id: 'mock-n-5',
          type: NotificationType.system,
          title: 'Verify your profile',
          body: 'Verified profiles get more attention.',
          createdAt: ago(const Duration(days: 6)),
          isRead: true,
        ),
      ]);
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  Future<T> _change<T>(T Function() change) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    return change();
  }

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      _fetch(() => List<AppNotification>.unmodifiable(_items), const []);

  @override
  Future<void> markRead(String id) => _change(() {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(isRead: true);
  });

  @override
  Future<void> markAllRead() => _change(() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  });
}
