/// Sign-in codes until an SMS provider is connected.
///
/// MOCK AND API: [developmentOtp] is accepted while SMS is off. A provider
/// must later send a random code; this value is not a secret and is not a
/// real verification.
abstract final class AuthRules {
  static const String developmentOtp = '123456';
}
