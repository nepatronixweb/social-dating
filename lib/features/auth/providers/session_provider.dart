// The session seam: UI and routing depend only on this file's types. The
// notifier behind it talks to `authRepositoryProvider`, which is the single
// place a mock authentication repository is chosen. Swapping in a real backend
// means changing that one provider; nothing here or in the UI changes.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import 'auth_session_notifier.dart';

/// Where the person is in the sign-in and onboarding journey.
///
/// This drives routing only. It is UX state, not authorisation: a real backend
/// must check access on every request.
enum AuthStatus {
  /// No session.
  loggedOut,

  /// A session existed but is no longer valid; the person must sign in again.
  sessionExpired,

  /// Phone verified; terms, privacy and age acknowledgements are pending.
  needsTerms,

  /// Terms accepted; birth date is pending.
  needsBirthDate,

  /// New account; gender has not been chosen.
  needsGender,

  /// Under the minimum age. Blocked from the dating UI.
  ineligible,

  /// Eligible; the profile still needs to be completed.
  incompleteProfile,

  /// Profile just completed; the completion screen is showing.
  onboardingComplete,

  /// Fully set up.
  loggedIn,
}

@immutable
class AuthSession {
  const AuthSession({
    required this.status,
    this.phone,
    this.phoneLabel,
    this.displayName,
    this.gender,
  });

  const AuthSession.loggedOut()
    : status = AuthStatus.loggedOut,
      phone = null,
      phoneLabel = null,
      displayName = null,
      gender = null;

  final AuthStatus status;

  /// Full number in E.164 form. Held in memory only; never persisted.
  final String? phone;

  /// A masked number safe to display and persist, e.g. `+977 ••••••4567`.
  final String? phoneLabel;
  final String? displayName;

  /// Chosen at profile completion. Used by the mock deck to decide who to show.
  final ProfileGender? gender;

  bool get isLoggedIn => status == AuthStatus.loggedIn;

  /// Whether the profile-completion requirement is satisfied. Discovery uses
  /// this for the swipe allowance; it is UX state, not authorisation.
  bool get hasCompletedProfile =>
      status == AuthStatus.onboardingComplete || status == AuthStatus.loggedIn;

  AuthSession copyWith({
    AuthStatus? status,
    String? phone,
    String? phoneLabel,
    String? displayName,
    ProfileGender? gender,
  }) => AuthSession(
    status: status ?? this.status,
    phone: phone ?? this.phone,
    phoneLabel: phoneLabel ?? this.phoneLabel,
    displayName: displayName ?? this.displayName,
    gender: gender ?? this.gender,
  );

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.status == status &&
      other.phone == phone &&
      other.phoneLabel == phoneLabel &&
      other.displayName == displayName &&
      other.gender == gender;

  @override
  int get hashCode =>
      Object.hash(status, phone, phoneLabel, displayName, gender);
}

/// Session operations the UI may call.
///
/// IMPORTANT: client-side session state only controls what the UI shows. It is
/// not a security boundary; a real backend must authorise every request.
abstract class SessionNotifier extends Notifier<AuthSession> {
  /// Asks the backend to send a one-time code to [phone] (E.164).
  /// Returns `true` when this number already has an account.
  Future<bool> sendCode(String phone);

  /// Exchanges [code] for a session. Throws an `AppFailure` on rejection.
  ///
  /// [login] is the returning-user path: phone, code, then the app.
  /// A new number continues into gender and full name.
  Future<void> signInWithPhone({
    required String phone,
    required String code,
    bool login = false,
  });

  Future<void> acceptTerms();

  /// Submits the birth date. Under-age results end in [AuthStatus.ineligible].
  Future<void> submitBirthDate(DateTime birthDate);

  Future<void> setGender(String gender);

  Future<void> completeProfile({
    required String displayName,
    String bio = '',
    List<String> interests = const [],
    String? city,
    String? gender,
  });

  /// Leaves the completion screen and enters the app.
  void finishOnboarding();

  void signOut();

  Future<void> deleteAccount();

  /// Updates the in-memory number. Only [AuthSession.phoneLabel] is persisted.
  void updatePhone(String e164);

  /// Marks the session as expired. A real implementation calls this when the
  /// backend rejects the session (for example an HTTP 401).
  void expireSession();

  /// Debug controls only: jump straight to [status] with sample data.
  void debugSimulate(AuthStatus status);

  /// Helper text shown on the sign-in screens in mock builds. `null` when
  /// verification is real. When non-null the UI must label the flow as a mock.
  String? get signInHint;
}

/// A one-time message to show after a session ends (consumed by the welcome
/// screen).
enum SessionNotice { signedOut, accountDeleted }

class SessionNoticeNotifier extends Notifier<SessionNotice?> {
  @override
  SessionNotice? build() => null;

  void show(SessionNotice notice) => state = notice;

  void clear() => state = null;
}

final sessionNoticeProvider =
    NotifierProvider<SessionNoticeNotifier, SessionNotice?>(
      SessionNoticeNotifier.new,
    );

final sessionProvider = NotifierProvider<SessionNotifier, AuthSession>(
  AuthSessionNotifier.new,
);
