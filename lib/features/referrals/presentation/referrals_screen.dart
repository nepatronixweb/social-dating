import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/referral_info.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/services/service_providers.dart';
import '../providers/referrals_providers.dart';

/// Referral overview: unique code, share/copy, and invite stats.
class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(referralInfoProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Invite friends'),
      body: AsyncValueView<ReferralInfo>(
        value: info,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(referralInfoProvider),
        data: (data) => SingleChildScrollView(
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ScreenHeader(
                  title: 'Share your invite',
                  subtitle:
                      'Friends use your code when they create an account. '
                      'You earn NPR 10 after a qualifying purchase is '
                      'confirmed.',
                ),
                Padding(
                  padding: AppSpacing.pagePadding,
                  child: _CodeCard(info: data),
                ),
                AppSpacing.gapXl,
                AppSection(
                  title: 'Your invites',
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Invites',
                          value: formatThousands(data.invitesSent),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: _Stat(
                          label: 'Joined',
                          value: formatThousands(data.friendsJoined),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: _Stat(
                          label: 'Pending',
                          value: formatNpr(data.pendingCommissionPaisa),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'More',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.history,
                        title: 'Referral history',
                        subtitle: 'Friends who used your code',
                        onTap: () => context.push(AppRoutes.referralHistory),
                      ),
                      MenuTile(
                        icon: AppIcons.wallet,
                        title: 'Commission earnings',
                        subtitle: 'Pending, approved, reversed and paid',
                        onTap: () => context.push(AppRoutes.referralEarnings),
                      ),
                      MenuTile(
                        icon: AppIcons.help,
                        title: 'Referral help',
                        subtitle: 'Eligibility and refund reversals',
                        onTap: () => context.push(AppRoutes.referralHelp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends ConsumerStatefulWidget {
  const _CodeCard({required this.info});

  final ReferralInfo info;

  @override
  ConsumerState<_CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends ConsumerState<_CodeCard> {
  final _claim = TextEditingController();
  bool _claiming = false;

  @override
  void dispose() {
    _claim.dispose();
    super.dispose();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.info.link));
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Invite link copied.',
      type: AppSnackType.success,
    );
  }

  Future<void> _share() async {
    await ref.read(sharePortProvider).shareText(widget.info.shareText);
  }

  Future<void> _submitClaim() async {
    final code = _claim.text.trim();
    if (code.isEmpty || _claiming) return;
    setState(() => _claiming = true);
    try {
      await ref.read(referralRepositoryProvider).claimCode(code);
      ref.read(referralRevisionProvider.notifier).bump();
      if (!mounted) return;
      _claim.clear();
      showAppSnackBar(
        context,
        'Invite applied. Your friend will see you in their history.',
        type: AppSnackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.borderLg,
        border: Border.all(color: context.palette.outlineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your referral code',
              style: context.text.labelMedium?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
            AppSpacing.gapSm,
            SelectableText(
              info.code,
              style: context.text.displaySmall?.copyWith(letterSpacing: 2),
            ),
            AppSpacing.gapMd,
            Text(
              'Invite link',
              style: context.text.labelMedium?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
            AppSpacing.gapXs,
            SelectableText(info.link, style: context.text.titleMedium),
            AppSpacing.gapXl,
            AppButton(
              label: 'Copy link',
              icon: AppIcons.copy,
              variant: AppButtonVariant.outlined,
              onPressed: _copyLink,
            ),
            AppSpacing.gapSm,
            AppButton(
              label: 'Share invite',
              icon: AppIcons.share,
              onPressed: _share,
            ),
            AppSpacing.gapXl,
            Text('Were you invited?', style: context.text.titleSmall),
            AppSpacing.gapSm,
            AppTextField(
              label: 'Friend\'s code',
              controller: _claim,
              hint: 'Optional',
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitClaim(),
              enabled: !_claiming,
            ),
            AppSpacing.gapSm,
            AppButton(
              label: 'Apply code',
              variant: AppButtonVariant.outlined,
              isLoading: _claiming,
              onPressed: _claiming ? null : _submitClaim,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        constraints: const BoxConstraints(minHeight: AppSizes.avatarLg),
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted,
          borderRadius: AppRadii.borderMd,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
