import 'dart:async';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../data/models/account_state.dart';
import '../../../data/models/country.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/session_snapshot.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/services/service_providers.dart';
import 'session_provider.dart';

/// The app's session state, held in Riverpod.
///
/// It talks to the `AuthRepository` seam, so it works the same with the mock
/// used today and a real backend later. After a restart it restores the last
/// known state from a small non-sensitive snapshot (no token, no phone number,
/// no birth date; see `SessionSnapshot`).
class AuthSessionNotifier extends SessionNotifier {
  /// [initial] skips restoring from storage. It exists for tests and debug
  /// tooling, so they can start in any state.
  AuthSessionNotifier({AuthSession? initial}) : _initial = initial;

  final AuthSession? _initial;
  AccountState? _account;

  /// Used only when a state was injected without an account (tests, debug).
  static const String _unknownAccountId = 'mock-account-unknown';

  /// Current account snapshot (null when logged out).
  AccountState? get account => _account;

  String get _accountId => _account?.id ?? _unknownAccountId;

  @override
  AuthSession build() {
    final initial = _initial;
    if (initial != null) return initial;

    final snapshot = ref.read(localPreferencesServiceProvider).sessionSnapshot;
    if (snapshot == null) return const AuthSession.loggedOut();

    final restored = AuthStatus.values
        .where((s) => s.name == snapshot.statusName)
        .firstOrNull;
    if (restored == null || restored == AuthStatus.loggedOut) {
      return const AuthSession.loggedOut();
    }

    _account = snapshot.account;

    // An old session needs signing in again. A blocked (under-age) account
    // stays blocked rather than expiring into a normal sign-in.
    final age = ref.read(clockProvider)().difference(snapshot.savedAt);
    final status =
        restored != AuthStatus.ineligible && age > AppConstants.sessionMaxAge
        ? AuthStatus.sessionExpired
        : restored;

    return AuthSession(
      status: status,
      phoneLabel: snapshot.phoneLabel,
      displayName: snapshot.displayName,
      gender: parseProfileGender(snapshot.gender),
    );
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  String? get signInHint => _repo.developmentNotice;

  void _set(AuthSession session) {
    state = session;
    _persist();
  }

  void _persist() {
    final prefs = ref.read(localPreferencesServiceProvider);
    if (state.status == AuthStatus.loggedOut) {
      unawaited(prefs.clearSessionSnapshot());
      return;
    }
    unawaited(
      prefs.saveSessionSnapshot(
        SessionSnapshot(
          statusName: state.status.name,
          savedAt: ref.read(clockProvider)(),
          phoneLabel: state.phoneLabel,
          displayName: state.displayName,
          gender: state.gender?.name,
          account: _account,
        ),
      ),
    );
  }

  /// Which status a signed-in account belongs in, from what the server knows.
  static AuthStatus statusFor(AccountState account) {
    if (account.isAgeEligible == false) return AuthStatus.ineligible;
    if (parseProfileGender(account.gender) == null) {
      return AuthStatus.needsGender;
    }
    if (account.displayName == null || account.displayName!.trim().isEmpty) {
      return AuthStatus.incompleteProfile;
    }
    return AuthStatus.loggedIn;
  }

  @override
  Future<bool> sendCode(String phone) => _repo.requestCode(phone);

  @override
  Future<void> signInWithPhone({
    required String phone,
    required String code,
    bool login = false,
  }) async {
    final prefs = ref.read(localPreferencesServiceProvider);
    final referralCode = login ? null : prefs.pendingReferralCode;
    final account = await _repo.verifyCode(
      phone: phone,
      code: code,
      resumeAccountId: state.status == AuthStatus.sessionExpired
          ? _account?.id
          : null,
      referralCode: referralCode,
      login: login,
    );
    await prefs.setPendingReferralCode(null);
    _account = account;
    // A registered number (login, or an account the repository already
    // finished) opens the app. A new number continues to gender then name.
    final status = login && account.isAgeEligible != false
        ? AuthStatus.loggedIn
        : statusFor(account);
    _set(
      AuthSession(
        status: status,
        phone: phone,
        phoneLabel: Country.mask(phone),
        displayName: account.displayName,
        gender:
            parseProfileGender(account.gender) ??
            (status == AuthStatus.loggedIn ? ProfileGender.male : null),
      ),
    );
  }

  @override
  Future<void> acceptTerms() async {
    _account = await _repo.acceptTerms(_accountId);
    _set(state.copyWith(status: AuthStatus.needsBirthDate));
  }

  @override
  Future<void> submitBirthDate(DateTime birthDate) async {
    final account = await _repo.submitBirthDate(_accountId, birthDate);
    _account = account;
    _set(state.copyWith(status: statusFor(account)));
  }

  @override
  Future<void> setGender(String gender) async {
    _account = await _repo.setGender(_accountId, gender);
    _set(
      state.copyWith(
        status: statusFor(_account!),
        gender: parseProfileGender(gender),
      ),
    );
  }

  @override
  Future<void> completeProfile({
    required String displayName,
    String bio = '',
    List<String> interests = const [],
    String? city,
    String? gender,
  }) async {
    _account = await _repo.completeProfile(
      _accountId,
      displayName,
      bio: bio,
      interests: interests,
      city: city,
      gender: gender,
    );
    _set(
      state.copyWith(
        status: statusFor(_account!),
        displayName: displayName,
        gender: parseProfileGender(gender) ?? state.gender,
      ),
    );
  }

  @override
  void finishOnboarding() {
    if (state.status != AuthStatus.onboardingComplete) return;
    _set(state.copyWith(status: AuthStatus.loggedIn));
  }

  @override
  void signOut() {
    unawaited(_repo.signOut());
    _account = null;
    ref.read(sessionNoticeProvider.notifier).show(SessionNotice.signedOut);
    _set(const AuthSession.loggedOut());
  }

  @override
  Future<void> deleteAccount() async {
    await _repo.deleteAccount(_accountId);
    _account = null;
    ref.read(sessionNoticeProvider.notifier).show(SessionNotice.accountDeleted);
    _set(const AuthSession.loggedOut());
  }

  @override
  void updatePhone(String e164) {
    _set(state.copyWith(phone: e164, phoneLabel: Country.mask(e164)));
  }

  @override
  void expireSession() {
    if (state.status == AuthStatus.loggedOut ||
        state.status == AuthStatus.sessionExpired) {
      return;
    }
    _set(state.copyWith(status: AuthStatus.sessionExpired));
  }

  @override
  void debugSimulate(AuthStatus status) {
    const phone = '+9779841234567';
    if (status == AuthStatus.loggedOut) {
      _account = null;
      _set(const AuthSession.loggedOut());
      return;
    }
    _account = AccountState(
      id: _unknownAccountId,
      termsAccepted: status != AuthStatus.needsTerms,
      isAgeEligible: switch (status) {
        AuthStatus.needsTerms || AuthStatus.needsBirthDate => null,
        AuthStatus.ineligible => false,
        _ => true,
      },
      gender: switch (status) {
        AuthStatus.needsGender ||
        AuthStatus.needsTerms ||
        AuthStatus.needsBirthDate ||
        AuthStatus.ineligible => null,
        _ => 'male',
      },
      displayName:
          status == AuthStatus.loggedIn ||
              status == AuthStatus.onboardingComplete
          ? 'Mock User'
          : null,
    );
    _set(
      AuthSession(
        status: status,
        phone: phone,
        phoneLabel: Country.mask(phone),
        displayName: _account!.displayName,
        gender: parseProfileGender(_account!.gender),
      ),
    );
  }
}
