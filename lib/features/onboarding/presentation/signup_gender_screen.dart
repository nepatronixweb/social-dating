import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../../data/models/profile.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/onboarding_page.dart';

/// First setup step for a new number: choose gender, then full name.
class SignupGenderScreen extends ConsumerStatefulWidget {
  const SignupGenderScreen({super.key});

  @override
  ConsumerState<SignupGenderScreen> createState() => _SignupGenderScreenState();
}

class _SignupGenderScreenState extends ConsumerState<SignupGenderScreen> {
  ProfileGender? _gender;
  bool _showError = false;
  bool _saving = false;
  AppFailure? _failure;

  Future<void> _submit() async {
    if (_saving) return;
    final gender = _gender;
    if (gender == null) {
      setState(() => _showError = true);
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(sessionProvider.notifier).setGender(gender.name);
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;

    return OnboardingPage(
      step: 1,
      total: 2,
      stepLabel: 'Gender',
      title: 'What\'s your',
      accentTitle: 'gender?',
      subtitle: 'Shown on your profile as Male, Female, LGBTQ+ or Other.',
      primaryAction: AppButton(
        label: 'Continue',
        icon: AppIcons.forward,
        iconOnEnd: true,
        pill: true,
        isLoading: _saving,
        onPressed: _submit,
      ),
      children: [
        if (_showError)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Select who you are.',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        for (final gender in ProfileGender.values) ...[
          Material(
            color: _gender == gender
                ? context.colors.primaryContainer
                : context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.borderMd,
              side: BorderSide(
                color: _gender == gender
                    ? context.colors.primary
                    : context.palette.outlineSoft,
                width: _gender == gender ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: AppRadii.borderMd,
              onTap: _saving
                  ? null
                  : () => setState(() {
                      _gender = gender;
                      _showError = false;
                    }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        gender.label,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: _gender == gender
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_gender == gender)
                      Icon(AppIcons.check, color: context.colors.primary),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.gapSm,
        ],
        if (failure != null) ...[
          AppSpacing.gapLg,
          FailureBanner(failure: failure, onRetry: _submit),
        ],
      ],
    );
  }
}
