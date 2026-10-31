import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/message_rules.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/connectivity_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/onboarding_progress.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/mock_repository_providers.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/mock_profile_repository.dart';
import '../../auth/providers/session_provider.dart';
import '../../chat/presentation/widgets/paid_message_dialog.dart';
import '../../discovery/presentation/widgets/match_celebration_dialog.dart';
import '../../discovery/presentation/widgets/paid_swipe_dialog.dart';
import '../../discovery/presentation/widgets/swipe_limit_sheet.dart';
import '../../discovery/providers/discovery_providers.dart';
import '../../discovery/providers/mock_discovery_providers.dart';
import '../../matches/providers/matches_providers.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../providers/theme_mode_provider.dart';

/// Debug-only gallery of the design system. All people shown come from the
/// mock-only repository and are labelled as such.
class DesignSystemPreviewScreen extends ConsumerWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final scenario = ref.watch(mockScenarioProvider);
    final session = ref.watch(sessionProvider);
    final offline = ref.watch(isOfflineProvider);
    final profiles = ref.watch(mockSuggestedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedContent(
            child: Padding(
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.lg,
                bottom: AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _MockBanner(),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Theme'),
                  AppSpacing.gapMd,
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(
                    title: 'Mock controls',
                    subtitle: 'Simulate app state without a backend',
                  ),
                  AppSpacing.gapMd,
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final status in AuthStatus.values)
                        InterestChip(
                          label: status.name,
                          selected: session.status == status,
                          onTap: () => ref
                              .read(sessionProvider.notifier)
                              .debugSimulate(status),
                        ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Session state. This screen is never redirected, so you can '
                    'flip states here and then open the app routes. Choosing '
                    'a state replaces the saved mock session.',
                    style: context.text.bodySmall,
                  ),
                  AppSpacing.gapLg,
                  const SectionHeader(
                    title: 'Mock sign-in test inputs',
                    subtitle: 'Development only. Nothing is really verified.',
                  ),
                  AppSpacing.gapSm,
                  for (final line
                      in ref
                              .watch(authRepositoryProvider)
                              .developmentTestInputs ??
                          const <String>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(line, style: context.text.bodyMedium),
                    ),
                  AppSpacing.gapLg,
                  const OnboardingProgress(step: 3, label: 'Terms'),
                  AppSpacing.gapMd,
                  const InlineMessage(
                    tone: InlineMessageTone.info,
                    message: 'Inline message (info).',
                  ),
                  AppSpacing.gapSm,
                  const InlineMessage(
                    tone: InlineMessageTone.error,
                    title: 'Something failed',
                    message: 'Inline message (error).',
                  ),
                  AppSpacing.gapMd,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulate offline'),
                    value: offline,
                    onChanged: (v) =>
                        ref.read(isOfflineProvider.notifier).setOffline(v),
                  ),
                  OfflineBanner(visible: offline),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Buttons'),
                  AppSpacing.gapMd,
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Secondary',
                    variant: AppButtonVariant.secondary,
                    icon: AppIcons.heartOutline,
                    onPressed: () {},
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Outlined',
                    variant: AppButtonVariant.outlined,
                    onPressed: () {},
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Text',
                    variant: AppButtonVariant.text,
                    onPressed: () {},
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Destructive',
                    variant: AppButtonVariant.destructive,
                    onPressed: () {},
                  ),
                  AppSpacing.gapSm,
                  const AppButton(label: 'Disabled', onPressed: null),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Loading',
                    isLoading: true,
                    onPressed: () {},
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Text fields'),
                  AppSpacing.gapMd,
                  const AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: AppIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppSpacing.gapMd,
                  const AppTextField(
                    label: 'Password',
                    obscureText: true,
                    prefixIcon: AppIcons.lock,
                    helper: 'Visibility toggle included.',
                  ),
                  AppSpacing.gapMd,
                  const AppTextField(
                    label: 'With error',
                    errorText: 'This is what an error looks like.',
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Avatars'),
                  AppSpacing.gapMd,
                  const Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      ProfileAvatar(name: 'Avery Sample', size: 48),
                      ProfileAvatar(
                        name: 'Jordan Example',
                        size: 64,
                        showRing: true,
                      ),
                      ProfileAvatar(
                        name: 'Riley Demo',
                        size: 64,
                        isOnline: true,
                        isVerified: true,
                      ),
                    ],
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Chips, pills & badges'),
                  AppSpacing.gapMd,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: const [
                      InterestChip(label: 'Hiking', selected: true),
                      InterestChip(label: 'Coffee'),
                      AppPill(label: 'New'),
                      AppPill(label: 'Nearby', tone: AppPillTone.neutral),
                      VerifiedBadge(),
                    ],
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Snackbars'),
                  AppSpacing.gapMd,
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final type in AppSnackType.values)
                        OutlinedButton(
                          onPressed: () => showAppSnackBar(
                            context,
                            'This is a ${type.name} message.',
                            type: type,
                          ),
                          child: Text(type.name),
                        ),
                    ],
                  ),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Loading'),
                  AppSpacing.gapMd,
                  const AppLoadingIndicator(message: 'Finding people nearby…'),
                  AppSpacing.gapLg,
                  const _SkeletonRow(),
                  AppSpacing.gapXl,
                  SectionHeader(
                    title: 'Cards & states',
                    subtitle: 'Mock repository, simulated latency',
                  ),
                  AppSpacing.gapMd,
                  SegmentedButton<MockScenario>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MockScenario.populated,
                        label: Text('Data'),
                      ),
                      ButtonSegment(
                        value: MockScenario.empty,
                        label: Text('Empty'),
                      ),
                      ButtonSegment(
                        value: MockScenario.failure,
                        label: Text('Error'),
                      ),
                    ],
                    selected: {scenario},
                    onSelectionChanged: (s) =>
                        ref.read(mockScenarioProvider.notifier).select(s.first),
                  ),
                  AppSpacing.gapLg,
                  SizedBox(
                    height: 420,
                    child: AsyncValueView<List<Profile>>(
                      value: profiles,
                      isEmpty: (list) => list.isEmpty,
                      onRetry: () =>
                          ref.invalidate(mockSuggestedProfilesProvider),
                      empty: const EmptyState(
                        icon: AppIcons.discover,
                        title: 'No one new right now',
                        message:
                            'You\'ve seen everyone nearby. Check back later.',
                      ),
                      data: (list) => ListView.separated(
                        scrollDirection: Axis.horizontal,
                        // Room for card shadows, which ListView would clip.
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => AppSpacing.gapMd,
                        itemBuilder: (context, i) => SizedBox(
                          width: 240,
                          child: ImageCard(
                            title: '${list[i].displayName}, ${list[i].age}',
                            subtitle: list[i].city,
                            placeholderSeed: i,
                            badge: list[i].isVerified
                                ? const _Chip(label: 'Verified')
                                : null,
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapXl,
                  const _SwipeMockControls(),
                  AppSpacing.gapXl,
                  const SectionHeader(title: 'Dialogs & sheets'),
                  AppSpacing.gapMd,
                  AppButton(
                    label: 'Confirmation dialog',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => showConfirmationDialog(
                      context,
                      title: 'Unmatch?',
                      message: 'You won\'t be able to message each other.',
                      confirmLabel: 'Unmatch',
                      isDestructive: true,
                    ),
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Bottom sheet',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => showAppBottomSheet<void>(
                      context,
                      title: 'Sample sheet',
                      builder: (_) => const AppTextField(label: 'Type here'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockBanner extends StatelessWidget {
  const _MockBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.errorContainer,
          borderRadius: AppRadii.borderMd,
        ),
        child: Row(
          children: [
            Icon(AppIcons.error, color: context.colors.onErrorContainer),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                'MOCK DATA: debug-only screen. All people and states here '
                'are fictional.',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.borderPill,
      ),
      child: Text(label, style: context.text.labelMedium),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 56, height: 56, borderRadius: AppRadii.borderPill),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140),
              AppSpacing.gapSm,
              SkeletonBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// Debug controls for the mock swipe "server": reach the daily-limit, paid and
/// insufficient-balance states without swiping dozens of times. Mock only.
class _SwipeMockControls extends ConsumerWidget {
  const _SwipeMockControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(mockSwipeRepositoryProvider);
    final matching = ref.watch(mockMatchingRepositoryProvider);

    void apply(void Function() change) {
      change();
      // Reload discovery so it reads the new mock state, and refresh likes,
      // matches and chat, which share it.
      ref.invalidate(discoveryControllerProvider);
      ref.read(matchingRevisionProvider.notifier).bump();
    }

    Widget action(String label, VoidCallback onPressed) => AppButton(
      label: label,
      variant: AppButtonVariant.secondary,
      expand: false,
      onPressed: onPressed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Swipe rules (mock)',
          subtitle: 'In-memory counters and wallet. The server decides later.',
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            action(
              'Male account (20 free)',
              () => apply(() => repo.viewerGender = ProfileGender.male),
            ),
            action(
              'Other account (no limit)',
              () => apply(() => repo.viewerGender = ProfileGender.female),
            ),
            action(
              '19 swipes used today',
              () => apply(() => repo.seedCounters(dailyUsed: 19)),
            ),
            action(
              '20 swipes used today',
              () => apply(() => repo.seedCounters(dailyUsed: 20)),
            ),
            action(
              '4 preview swipes used',
              () => apply(() => repo.seedCounters(previewUsed: 4)),
            ),
            action(
              'Balance NPR 0.00',
              () => apply(() => repo.balancePaisa = 0),
            ),
            action(
              'Balance NPR 0.05',
              () => apply(() => repo.balancePaisa = 5),
            ),
            action(
              'Balance NPR 1.00',
              () => apply(() => repo.balancePaisa = 100),
            ),
            action(
              'LGBTQ+ account (daily preference)',
              () => apply(() => repo.viewerGender = ProfileGender.lgbtq),
            ),
            action('Reset all swipes', () => apply(repo.reset)),
            action(
              'Reset likes, matches and chats',
              () => apply(matching.reset),
            ),
            action('Reset mock subscriptions', () {
              ref.read(mockSubscriptionRepositoryProvider).reset();
              ref.read(subscriptionRevisionProvider.notifier).bump();
            }),
          ],
        ),
        AppSpacing.gapLg,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            action(
              'Match celebration',
              () => showMatchCelebration(
                context,
                profile: mockProfiles[1],
                canViewMatches: true,
              ),
            ),
            action(
              'Paid swipe dialog',
              () => showPaidSwipeDialog(
                context,
                costPaisa: 10,
                balancePaisa: 40,
                freeLimit: 20,
              ),
            ),
            action(
              'Paid message dialog',
              () => showPaidMessageDialog(
                context,
                quote: MessageQuote.fromText(
                  'See you Friday',
                  senderPays: true,
                ),
                balancePaisa: 100,
              ),
            ),
            action(
              'Fail next chat send',
              () => apply(() => matching.messaging.failNextSend = true),
            ),
            action('Swipe limit sheet', () async {
              final quota = await repo.fetchQuota();
              if (!context.mounted) return;
              await showSwipeLimitSheet(
                context,
                quota: quota,
                now: ref.read(clockProvider)(),
              );
            }),
          ],
        ),
      ],
    );
  }
}
