import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_notification.dart';
import '../../../data/repositories/repository_providers.dart';

/// Counts mark-read changes so the inbox and the bell badge refetch together.
class NotificationRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final notificationRevisionProvider =
    NotifierProvider<NotificationRevision, int>(NotificationRevision.new);

/// Not auto-disposed: the bell badge reads it from every tab.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(notificationRevisionProvider);
  return ref.watch(notificationRepositoryProvider).fetchNotifications();
}, retry: (_, _) => null);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
