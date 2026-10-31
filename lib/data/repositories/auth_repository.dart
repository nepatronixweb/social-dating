import '../models/account_state.dart';

/// Authentication and onboarding operations.
///
/// Every method may throw an `AppFailure` (network, rejected code, and so on).
/// Debug builds use `MockAuthRepository`. API mode uses `ApiAuthRepository`
/// against the confirmed `/v1` contract.
abstract class AuthRepository {
  /// Requests a one-time code for [phone] (E.164).
  ///
  /// Returns `true` when this number already has an account.
  Future<bool> requestCode(String phone);

  /// Verifies [code] for [phone]. [resumeAccountId] is set when the person is
  /// signing back in to an account whose session expired. [login] is the
  /// returning-user path: a finished account opens the app, not first-time
  /// setup. A number that already has an account is treated as returning even
  /// when [login] is false.
  Future<AccountState> verifyCode({
    required String phone,
    required String code,
    String? resumeAccountId,
    String? referralCode,
    bool login = false,
  });

  Future<AccountState> acceptTerms(String accountId);

  /// Records the birth date and returns whether the person is old enough.
  Future<AccountState> submitBirthDate(String accountId, DateTime birthDate);

  Future<AccountState> setGender(String accountId, String gender);

  Future<AccountState> completeProfile(
    String accountId,
    String displayName, {
    String bio = '',
    List<String> interests = const [],
    String? city,
    String? gender,
  });

  Future<void> deleteAccount(String accountId);

  /// Ends the server session when one exists. The mock is a no-op.
  Future<void> signOut();

  /// Text for the sign-in screens when this repository is not real
  /// verification (a development mock). `null` for a real implementation.
  String? get developmentNotice;

  /// A mock repository returns the dev-only test inputs it understands so the
  /// debug gallery can list them. `null` for a real implementation.
  List<String>? get developmentTestInputs;
}
