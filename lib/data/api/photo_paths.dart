/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class PhotoApiPaths {
  static const mine = '/v1/me/photos';
  static const order = '/v1/me/photos/order';
  static String one(String id) => '/v1/me/photos/$id';
}
