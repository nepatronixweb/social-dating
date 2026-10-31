// ============================================================================
// MOCK AUTHENTICATION REPOSITORY: DEVELOPMENT ONLY. NOT REAL VERIFICATION.
//
// No SMS is sent and no phone number is ever checked. The "server" is a map in
// memory and the one-time codes are fixed, published values below. Nothing
// here proves who anyone is, and nothing from it may be treated as security.
//
// Development-only test inputs (also listed in the README and the debug
// gallery):
//
//   Codes (6 digits)
//     123456   accepted
//     000000   rejected as EXPIRED
//     111111   rejected with a generic authentication FAILURE (every time)
//     222222   NETWORK error the first time, accepted on retry
//     other    rejected as INCORRECT
//
//   Phone numbers (national number ending)
//     ...0000  sending the code fails with a NETWORK error once, then works
//     ...1111  sending the code fails with a generic FAILURE (every time)
// ============================================================================

import '../../core/constants/auth_rules.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/age.dart';
import '../models/account_state.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.latency = const Duration(milliseconds: 700),
    DateTime Function()? now,
    Iterable<AccountState> seed = const [],
  }) : _now = now ?? DateTime.now {
    for (final account in seed) {
      _accounts[account.id] = account;
    }
  }

  static const String acceptedCode = AuthRules.developmentOtp;
  static const String expiredCode = '000000';
  static const String failureCode = '111111';
  static const String transientNetworkCode = '222222';
  static const String networkFailurePhoneSuffix = '0000';
  static const String genericFailurePhoneSuffix = '1111';

  /// Simulated network delay. Use [Duration.zero] in tests.
  final Duration latency;
  final DateTime Function() _now;

  final Map<String, AccountState> _accounts = {};
  final Map<String, String> _accountIdByPhone = {};
  final Set<String> _transientFailures = {};
  int _nextId = 1;

  Future<void> _delay() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  String? get developmentNotice =>
      'Development mock: no SMS is sent and nothing is verified. '
      'Use code $acceptedCode to continue.';

  @override
  List<String> get developmentTestInputs => const [
    'Code 123456: accepted',
    'Code 000000: expired',
    'Code 111111: generic sign-in failure',
    'Code 222222: network error once, then accepted',
    'Any other code: incorrect',
    'Phone ending 0000: network error once when sending',
    'Phone ending 1111: generic failure when sending',
  ];

  @override
  Future<bool> requestCode(String phone) async {
    await _delay();
    if (phone.endsWith(genericFailurePhoneSuffix)) {
      throw const AuthenticationFailure();
    }
    if (phone.endsWith(networkFailurePhoneSuffix) &&
        _transientFailures.add('send:$phone')) {
      throw const NetworkFailure();
    }
    return _accountIdByPhone.containsKey(phone);
  }

  @override
  Future<AccountState> verifyCode({
    required String phone,
    required String code,
    String? resumeAccountId,
    String? referralCode,
    bool login = false,
  }) async {
    await _delay();

    switch (code) {
      case acceptedCode:
        break;
      case expiredCode:
        throw const CodeExpiredFailure();
      case failureCode:
        throw const AuthenticationFailure();
      case transientNetworkCode:
        if (_transientFailures.add('verify:$phone')) {
          throw const NetworkFailure();
        }
      default:
        throw const InvalidCodeFailure();
    }

    final existingId = _accountIdByPhone[phone];
    if (existingId != null) {
      return _readyForLogin(_accounts[existingId]!);
    }

    // Signing back in to an account restored from a previous session.
    if (resumeAccountId != null && _accounts.containsKey(resumeAccountId)) {
      _accountIdByPhone[phone] = resumeAccountId;
      return _readyForLogin(_accounts[resumeAccountId]!);
    }

    final account = AccountState(id: 'mock-account-${_nextId++}');
    _accounts[account.id] = account;
    _accountIdByPhone[phone] = account.id;
    return login ? _readyForLogin(account) : _startSignup(account);
  }

  AccountState _readyForLogin(AccountState account) {
    if (account.isAgeEligible == false) return account;
    return _save(
      account.copyWith(
        termsAccepted: true,
        isAgeEligible: account.isAgeEligible ?? true,
        displayName: account.displayName ?? 'You',
        gender: account.gender ?? 'male',
      ),
    );
  }

  AccountState _startSignup(AccountState account) => _save(
    account.copyWith(termsAccepted: true, isAgeEligible: true),
  );

  AccountState _account(String id) =>
      _accounts.putIfAbsent(id, () => AccountState(id: id));

  AccountState _save(AccountState account) => _accounts[account.id] = account;

  @override
  Future<AccountState> acceptTerms(String accountId) async {
    await _delay();
    return _save(_account(accountId).copyWith(termsAccepted: true));
  }

  @override
  Future<AccountState> submitBirthDate(
    String accountId,
    DateTime birthDate,
  ) async {
    await _delay();
    final eligible = AgeEligibility.isEligible(birthDate, _now());
    return _save(_account(accountId).copyWith(isAgeEligible: eligible));
  }

  @override
  Future<AccountState> setGender(String accountId, String gender) async {
    await _delay();
    return _save(_account(accountId).copyWith(gender: gender));
  }

  @override
  Future<AccountState> completeProfile(
    String accountId,
    String displayName, {
    String bio = '',
    List<String> interests = const [],
    String? city,
    String? gender,
  }) async {
    await _delay();
    // Session routing only needs the name. Profile details are persisted by the API.
    assert(bio.length <= 300);
    assert(interests.length <= 8);
    assert(city == null || city.isNotEmpty);
    assert(gender == null || gender.isNotEmpty);
    return _save(
      _account(accountId).copyWith(displayName: displayName, gender: gender),
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    await _delay();
    _accounts.remove(accountId);
    _accountIdByPhone.removeWhere((_, id) => id == accountId);
  }

  @override
  Future<void> signOut() async {}
}
