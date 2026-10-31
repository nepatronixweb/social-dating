import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../data/models/profile.dart';
import '../../auth/providers/session_provider.dart';
import '../../discovery/providers/discovery_providers.dart';
import '../../onboarding/presentation/widgets/onboarding_page.dart';

/// The last setup step, for people who passed the age check. Completing it
/// moves the session to the completion screen.
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final Set<String> _interests = {};
  ProfileGender? _gender;
  String? _city;
  bool _showInterestError = false;
  bool _showGenderError = false;
  bool _showCityError = false;
  bool _saving = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _toggle(String interest) {
    setState(() {
      if (!_interests.remove(interest)) {
        if (_interests.length < AppConstants.maxInterests) {
          _interests.add(interest);
        }
      }
      _showInterestError = false;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final valid = _formKey.currentState!.validate();
    final enough = _interests.length >= AppConstants.minInterests;
    final hasGender = _gender != null;
    final hasCity = _city != null;
    setState(() {
      _showInterestError = !enough;
      _showGenderError = !hasGender;
      _showCityError = !hasCity;
    });
    if (!valid || !enough || !hasGender || !hasCity) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .completeProfile(
            displayName: _name.text.trim(),
            bio: _bio.text.trim(),
            interests: _interests.toList(),
            city: _city,
            gender: _gender?.name,
          );
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
    // People may try a few swipes before finishing. The count comes from the
    // swipe repository (mock for now).
    final previewLeft = ref
        .watch(swipeQuotaProvider)
        .maybeWhen(data: (quota) => quota.previewRemaining, orElse: () => 0);

    return OnboardingPage(
      secondaryAction: previewLeft > 0
          ? AppButton(
              label:
                  'Explore first ($previewLeft '
                  '${previewLeft == 1 ? 'swipe' : 'swipes'} left)',
              variant: AppButtonVariant.text,
              onPressed: _saving ? null : () => context.go(AppRoutes.discover),
            )
          : null,
      step: 5,
      stepLabel: 'Profile',
      title: 'Tell us about you',
      subtitle: 'Start with your gender, then a few details for your profile.',
      primaryAction: AppButton(
        label: 'Finish',
        icon: AppIcons.forward,
        iconOnEnd: true,
        pill: true,
        isLoading: _saving,
        onPressed: _submit,
      ),
      children: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Gender', style: context.text.titleLarge),
              ),
              AppSpacing.gapXs,
              Text(
                _showGenderError
                    ? 'Select who you are.'
                    : 'Required. Shown on your profile as Male, Female, LGBTQ+ or Other.',
                style: context.text.bodySmall?.copyWith(
                  color: _showGenderError
                      ? context.colors.error
                      : context.palette.textMuted,
                ),
              ),
              AppSpacing.gapMd,
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
                            _showGenderError = false;
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
              AppSpacing.gapLg,
              AppTextField(
                label: 'First name',
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                validator: Validators.displayName,
              ),
              AppSpacing.gapXl,
              AppDropdownField<String>(
                key: const ValueKey('city-dropdown'),
                label: 'City',
                hint: 'Select city',
                helperText: _showCityError ? null : 'Where you are based.',
                errorText: _showCityError ? 'Choose a city.' : null,
                value: _city,
                items: AppConstants.cityOptions,
                itemLabel: (city) => city,
                enabled: !_saving,
                onChanged: (city) => setState(() {
                  _city = city;
                  _showCityError = false;
                }),
              ),
              AppSpacing.gapLg,
              AppTextField(
                label: 'About you (optional)',
                controller: _bio,
                enabled: !_saving,
                maxLines: 4,
                maxLength: Validators.maxBioLength,
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.bio,
              ),
            ],
          ),
        ),
        AppSpacing.gapXl,
        Semantics(
          header: true,
          child: Text('Interests', style: context.text.titleLarge),
        ),
        AppSpacing.gapXs,
        Text(
          'Pick at least ${AppConstants.minInterests} '
          '(${_interests.length} selected).',
          style: context.text.bodySmall?.copyWith(
            color: _showInterestError
                ? context.colors.error
                : context.palette.textMuted,
          ),
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final interest in AppConstants.interestOptions)
              InterestChip(
                label: interest,
                selected: _interests.contains(interest),
                onTap: _saving ? null : () => _toggle(interest),
              ),
          ],
        ),
        if (failure != null) ...[
          AppSpacing.gapLg,
          FailureBanner(failure: failure, onRetry: _submit),
        ],
      ],
    );
  }
}
