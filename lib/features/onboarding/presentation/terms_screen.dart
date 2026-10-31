import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/acknowledgement_tile.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/onboarding_page.dart';

/// Terms of Service, Privacy Policy and age acknowledgements. All three must
/// be ticked to continue; nothing is pre-ticked.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _age = false;
  bool _saving = false;
  AppFailure? _failure;

  bool get _allAccepted => _terms && _privacy && _age;

  Future<void> _continue() async {
    if (!_allAccepted || _saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(sessionProvider.notifier).acceptTerms();
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _readLink(String route) => TextButton.icon(
    onPressed: () => context.push(route),
    iconAlignment: IconAlignment.end,
    icon: const Icon(AppIcons.chevronRight, size: AppSizes.iconSm),
    label: const Text('Read'),
  );

  @override
  Widget build(BuildContext context) {
    final failure = _failure;

    return OnboardingPage(
      step: 3,
      stepLabel: 'Terms',
      title: 'Before you',
      accentTitle: 'start',
      subtitle: 'Please review and agree to continue.',
      primaryAction: AppButton(
        label: 'Agree and continue',
        icon: AppIcons.forward,
        iconOnEnd: true,
        pill: true,
        isLoading: _saving,
        onPressed: _allAccepted ? _continue : null,
      ),
      children: [
        AcknowledgementTile(
          value: _terms,
          onChanged: _saving ? null : (v) => setState(() => _terms = v),
          title: 'I agree to the Terms of Service',
          trailing: _readLink(AppRoutes.legalTerms),
        ),
        AppSpacing.gapMd,
        AcknowledgementTile(
          value: _privacy,
          onChanged: _saving ? null : (v) => setState(() => _privacy = v),
          title: 'I have read the Privacy Policy',
          trailing: _readLink(AppRoutes.legalPrivacy),
        ),
        AppSpacing.gapMd,
        AcknowledgementTile(
          value: _age,
          onChanged: _saving ? null : (v) => setState(() => _age = v),
          title: 'I am 18 years old or older',
          subtitle: 'Social Dating is only for adults.',
        ),
        AppSpacing.gapLg,
        const _NextStepHint(),
        if (failure != null) ...[
          AppSpacing.gapLg,
          FailureBanner(failure: failure, onRetry: _continue),
        ],
      ],
    );
  }
}

class _NextStepHint extends StatelessWidget {
  const _NextStepHint();

  static const _copy = 'You\'ll confirm your date of birth in the next step.';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: AppRadii.borderPill,
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.55),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  AppIcons.info,
                  size: AppSizes.iconSm,
                  color: context.colors.primary,
                ),
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                _copy,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
