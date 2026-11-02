import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/main_shell.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/session_expired_screen.dart';
import '../../features/auth/presentation/verify_screen.dart';
import '../../features/auth/providers/session_provider.dart';
import '../../features/chat/presentation/chat_conversation_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../data/models/profile.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/discovery/presentation/profile_detail_screen.dart';
import '../../features/likes/presentation/likes_screen.dart';
import '../../features/matches/presentation/match_detail_screen.dart';
import '../../features/matches/presentation/match_history_screen.dart';
import '../../features/matches/presentation/match_preferences_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/birth_date_screen.dart';
import '../../features/onboarding/presentation/ineligible_screen.dart';
import '../../features/onboarding/presentation/onboarding_complete_screen.dart';
import '../../features/onboarding/presentation/signup_gender_screen.dart';
import '../../features/onboarding/presentation/signup_name_screen.dart';
import '../../features/onboarding/presentation/terms_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profile/personal_info/personal_profile_completion.dart';
import '../../features/profile/presentation/personal_info_section_screen.dart';
import '../../features/profile/presentation/personal_information_screen.dart';
import '../../features/profile/presentation/profile_photos_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/referrals/presentation/commission_detail_screen.dart';
import '../../features/referrals/presentation/referral_earnings_screen.dart';
import '../../features/referrals/presentation/referral_help_screen.dart';
import '../../features/referrals/presentation/referral_history_screen.dart';
import '../../features/referrals/presentation/referrals_screen.dart';
import '../../features/safety/presentation/blocked_users_screen.dart';
import '../../features/safety/presentation/report_submitted_screen.dart';
import '../../features/safety/presentation/report_user_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/settings/presentation/accessibility_settings_screen.dart';
import '../../features/settings/presentation/account_screen.dart';
import '../../features/settings/presentation/change_phone_screen.dart';
import '../../features/settings/presentation/delete_account_screen.dart';
import '../../features/settings/presentation/design_system_preview_screen.dart';
import '../../features/settings/presentation/help_center_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/billing_help_screen.dart';
import '../../features/subscription/presentation/checkout_screen.dart';
import '../../features/subscription/presentation/payment_method_screen.dart';
import '../../features/subscription/presentation/payment_status_screen.dart';
import '../../features/subscription/presentation/plan_detail_screen.dart';
import '../../features/subscription/presentation/purchase_history_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/wallet/presentation/payout_help_screen.dart';
import '../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../features/wallet/presentation/transaction_history_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/wallet/presentation/welcome_bonus_screen.dart';
import '../../features/wallet/presentation/withdrawal_detail_screen.dart';
import '../../features/wallet/presentation/withdrawal_eligibility_screen.dart';
import '../../features/wallet/presentation/withdrawal_history_screen.dart';
import '../../features/wallet/presentation/withdrawal_request_screen.dart';
import '../constants/subscription_rules.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../widgets/error_state.dart';
import 'app_routes.dart';
import 'route_guards.dart';

/// Builds the app router.
///
/// [status] is read on every navigation by the redirect, and [refresh] tells
/// the router to re-evaluate the redirect when the session changes. The guard
/// is a UX convenience, not security: see [sessionRedirect].
GoRouter buildRouter({
  String initialLocation = AppRoutes.splash,
  required AuthStatus Function() status,
  Listenable? refresh,
}) {
  // One key per router instance (a shared global key would clash in tests).
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) =>
        sessionRedirect(status(), state.uri.toString()),
    errorBuilder: (context, state) =>
        RouteErrorScreen(onHome: () => context.go(AppRoutes.welcome)),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            _fadePage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (context, state) =>
            PhoneScreen(login: state.uri.queryParameters['mode'] == 'login'),
      ),
      GoRoute(
        path: AppRoutes.authVerify,
        builder: (context, state) => VerifyScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          login: state.uri.queryParameters['mode'] == 'login',
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionExpired,
        pageBuilder: (context, state) =>
            _fadePage(state, const SessionExpiredScreen()),
      ),
      GoRoute(
        path: AppRoutes.legalTerms,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: AppRoutes.legalPrivacy,
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: AppRoutes.onboardingTerms,
        pageBuilder: (context, state) => _fadePage(state, const TermsScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingBirthDate,
        pageBuilder: (context, state) =>
            _fadePage(state, const BirthDateScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingIneligible,
        pageBuilder: (context, state) =>
            _fadePage(state, const IneligibleScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingGender,
        pageBuilder: (context, state) =>
            _fadePage(state, const SignupGenderScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileCompletion,
        pageBuilder: (context, state) =>
            _fadePage(state, const SignupNameScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingComplete,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingCompleteScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (context, state) => const DiscoveryScreen(),
                routes: [
                  GoRoute(
                    path: 'profile/:id',
                    // Full screen, above the bottom navigation. The profile
                    // is passed as `extra`; a direct link falls back to the
                    // current deck.
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => ProfileDetailScreen(
                      profileId: state.pathParameters['id']!,
                      profile: state.extra is Profile
                          ? state.extra! as Profile
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.likes,
                builder: (context, state) => const LikesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.matches,
                builder: (context, state) => const MatchesScreen(),
                routes: [
                  // Static paths first, so they are not read as a match id.
                  GoRoute(
                    path: 'preferences',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const MatchPreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const MatchHistoryScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    // Full screen, above the bottom navigation.
                    parentNavigatorKey: rootKey,
                    builder: (context, state) =>
                        MatchDetailScreen(matchId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    // Full screen, above the bottom navigation.
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => ChatConversationScreen(
                      chatId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'personal-info',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) =>
                        const PersonalInformationScreen(),
                    routes: [
                      GoRoute(
                        path: ':section',
                        parentNavigatorKey: rootKey,
                        builder: (context, state) {
                          final raw = state.pathParameters['section'] ?? '';
                          final section = PersonalProfileSection.values
                              .where((s) => s.name == raw)
                              .firstOrNull;
                          if (section == null) {
                            return const PersonalInformationScreen();
                          }
                          return PersonalInfoSectionScreen(section: section);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'photos',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const ProfilePhotosScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const PurchaseHistoryScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const BillingHelpScreen(),
          ),
          GoRoute(
            path: 'checkout',
            builder: (context, state) => CheckoutScreen(
              planId:
                  state.uri.queryParameters['plan'] ??
                  SubscriptionRules.standardPlanId,
              referralLinked: state.uri.queryParameters['referral'] == '1',
              amountPaisa: AppRoutes.paisaFromQuery(state.uri.queryParameters),
            ),
          ),
          GoRoute(
            path: 'pay',
            builder: (context, state) => PaymentMethodScreen(
              planId:
                  state.uri.queryParameters['plan'] ??
                  SubscriptionRules.standardPlanId,
              referralLinked: state.uri.queryParameters['referral'] == '1',
              amountPaisa: AppRoutes.paisaFromQuery(state.uri.queryParameters),
            ),
          ),
          GoRoute(
            path: 'plan/:id',
            builder: (context, state) => PlanDetailScreen(
              planId: state.pathParameters['id']!,
              amountPaisa: AppRoutes.paisaFromQuery(state.uri.queryParameters),
            ),
          ),
          GoRoute(
            path: 'status/:id',
            builder: (context, state) =>
                PaymentStatusScreen(purchaseId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
        routes: [
          GoRoute(
            path: 'activity',
            builder: (context, state) => const TransactionHistoryScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => TransactionDetailScreen(
                  transactionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'welcome',
            builder: (context, state) => const WelcomeBonusScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const PayoutHelpScreen(),
          ),
          GoRoute(
            path: 'withdraw',
            builder: (context, state) => const WithdrawalEligibilityScreen(),
            routes: [
              GoRoute(
                path: 'request',
                builder: (context, state) => const WithdrawalRequestScreen(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const WithdrawalHistoryScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => WithdrawalDetailScreen(
                  withdrawalId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.referrals,
        builder: (context, state) => const ReferralsScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const ReferralHistoryScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const ReferralHelpScreen(),
          ),
          GoRoute(
            path: 'earnings',
            builder: (context, state) => const ReferralEarningsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CommissionDetailScreen(
                  commissionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
        routes: [
          GoRoute(
            path: 'preferences',
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacySettingsScreen(),
          ),
          GoRoute(
            path: 'accessibility',
            builder: (context, state) => const AccessibilitySettingsScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const HelpCenterScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.safety,
        builder: (context, state) => const SafetyScreen(),
        routes: [
          GoRoute(
            path: 'blocked',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'report/submitted',
            builder: (context, state) => const ReportSubmittedScreen(),
          ),
          GoRoute(
            path: 'report',
            builder: (context, state) => ReportUserScreen(
              subjectName: state.uri.queryParameters['name'],
              reportedAccountId: state.uri.queryParameters['id'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const AccountScreen(),
        routes: [
          GoRoute(
            path: 'phone',
            builder: (context, state) => const ChangePhoneScreen(),
          ),
          GoRoute(
            path: 'delete',
            builder: (context, state) => const DeleteAccountScreen(),
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.designPreview,
          builder: (context, state) => const DesignSystemPreviewScreen(),
        ),
    ],
  );
}

/// Where the app starts. Overridden in tests to open a specific screen.
final initialLocationProvider = Provider<String>((ref) => AppRoutes.splash);

final routerProvider = Provider<GoRouter>((ref) {
  // Bumped whenever the session changes so the redirect re-runs.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  final router = buildRouter(
    initialLocation: ref.read(initialLocationProvider),
    status: () => ref.read(sessionProvider).status,
    refresh: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    transitionsBuilder: (context, animation, secondary, child) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduce) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.standard),
        child: child,
      );
    },
  );
}

/// Shown for unknown routes / navigation errors.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          icon: AppIcons.error,
          title: 'Page not found',
          message: 'That page doesn\'t exist or has moved.',
          retryLabel: 'Go to start',
          onRetry: onHome,
        ),
      ),
    );
  }
}
