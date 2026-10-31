import '../../features/auth/providers/session_provider.dart';
import 'app_routes.dart';

/// The one screen each in-progress session belongs on.
String homeFor(AuthStatus status) => switch (status) {
  AuthStatus.loggedOut => AppRoutes.welcome,
  AuthStatus.sessionExpired => AppRoutes.sessionExpired,
  AuthStatus.needsTerms => AppRoutes.onboardingTerms,
  AuthStatus.needsBirthDate => AppRoutes.onboardingBirthDate,
  AuthStatus.needsGender => AppRoutes.onboardingGender,
  AuthStatus.ineligible => AppRoutes.onboardingIneligible,
  AuthStatus.incompleteProfile => AppRoutes.profileCompletion,
  AuthStatus.onboardingComplete => AppRoutes.onboardingComplete,
  AuthStatus.loggedIn => AppRoutes.discover,
};

/// Decides where a session in [status] should be sent when it requests
/// [location]. Returns `null` to allow the navigation.
///
/// This is UX routing only: it prevents showing screens that make no sense for
/// the current session (and keeps under-age people out of the dating UI in the
/// mock flow). It is NOT access control: client code can always be bypassed,
/// so a real backend must authorise every request itself.
String? sessionRedirect(AuthStatus status, String location) {
  final path = Uri.parse(location).path;

  // Always reachable: splash, debug tools and the legal documents.
  if (path == AppRoutes.splash ||
      path.startsWith('/dev') ||
      path.startsWith('/legal')) {
    return null;
  }

  bool underAny(Iterable<String> prefixes) =>
      prefixes.any((p) => path == p || path.startsWith('$p/'));

  final isProtected = underAny(AppRoutes.protectedPrefixes);
  final isAuthFlow = path == AppRoutes.welcome || path.startsWith('/auth');
  final isOnboarding = AppRoutes.onboardingPaths.contains(path);
  final isExpiredScreen = path == AppRoutes.sessionExpired;

  // Unknown paths are never redirected, so they reach the not-found screen.
  if (!isProtected && !isAuthFlow && !isOnboarding && !isExpiredScreen) {
    return null;
  }

  switch (status) {
    case AuthStatus.loggedOut:
      return (isProtected || isOnboarding || isExpiredScreen)
          ? AppRoutes.welcome
          : null;
    case AuthStatus.sessionExpired:
      // Signing in again goes through the auth screens, but the welcome
      // screen would hide why the person was signed out.
      return (isProtected || isOnboarding || path == AppRoutes.welcome)
          ? AppRoutes.sessionExpired
          : null;
    case AuthStatus.loggedIn:
      return (isAuthFlow || isOnboarding || isExpiredScreen)
          ? AppRoutes.discover
          : null;
    case AuthStatus.incompleteProfile:
      // Discovery is open before the profile is complete so the first few
      // swipes can happen during onboarding. The screen itself enforces the
      // swipe preview limit (UX only; a server must enforce it for real).
      if (underAny([AppRoutes.discover])) return null;
      return path == AppRoutes.profileCompletion
          ? null
          : AppRoutes.profileCompletion;
    case AuthStatus.needsTerms:
    case AuthStatus.needsBirthDate:
    case AuthStatus.needsGender:
    case AuthStatus.ineligible:
    case AuthStatus.onboardingComplete:
      // Mid-onboarding (or blocked): exactly one screen is available.
      final home = homeFor(status);
      return path == home ? null : home;
  }
}
