/// Relative paths confirmed by `backend/CONTRACT.md`.
///
/// Hosts come only from `--dart-define=API_BASE_URL`. These values are paths,
/// never origins.
abstract final class AuthApiPaths {
  static const requestCode = '/v1/auth/code';
  static const verify = '/v1/auth/verify';
  static const refresh = '/v1/auth/refresh';
  static const signOut = '/v1/auth/sign-out';
  static const me = '/v1/me';
  static const terms = '/v1/me/terms';
  static const age = '/v1/me/age';
  static const gender = '/v1/me/gender';
  static const profile = '/v1/me/profile';
}
