/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class NotificationApiPaths {
  static const list = '/v1/notifications';
  static const readAll = '/v1/notifications/read-all';
  static String read(String id) => '/v1/notifications/$id/read';
}
