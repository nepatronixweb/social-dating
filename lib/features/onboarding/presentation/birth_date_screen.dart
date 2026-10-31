import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/age.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/date_of_birth_input.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../../core/widgets/inline_message.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/onboarding_page.dart';

/// Date of birth entry with live 18+ feedback. Submitting an under-age date
/// moves the session to the ineligible state, which blocks the dating UI.
class BirthDateScreen extends ConsumerStatefulWidget {
  const BirthDateScreen({super.key});

  @override
  ConsumerState<BirthDateScreen> createState() => _BirthDateScreenState();
}

class _BirthDateScreenState extends ConsumerState<BirthDateScreen> {
  BirthDateParse _parse = const BirthDateParse.invalid(
    BirthDateIssue.incomplete,
  );
  bool _saving = false;
  AppFailure? _failure;

  DateTime get _today => ref.read(clockProvider)();

  Future<void> _submit() async {
    final date = _parse.date;
    if (!_parse.isValid || date == null || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(sessionProvider.notifier).submitBirthDate(date);
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _parse.date;
    final failure = _failure;
    final eligible = date == null
        ? null
        : AgeEligibility.isEligible(date, _today);

    return OnboardingPage(
      step: 4,
      stepLabel: 'Date of birth',
      title: 'When were you born?',
      subtitle: 'You must be ${AgeEligibility.minimumAge} or older.',
      primaryAction: AppButton(
        label: 'Continue',
        icon: AppIcons.forward,
        iconOnEnd: true,
        pill: true,
        isLoading: _saving,
        onPressed: _parse.isValid ? _submit : null,
      ),
      children: [
        DateOfBirthInput(
          today: _today,
          enabled: !_saving,
          autofocus: true,
          onChanged: (parse) => setState(() {
            _parse = parse;
            _failure = null;
          }),
          onSubmitted: _submit,
        ),
        AppSpacing.gapLg,
        if (eligible == true)
          const InlineMessage(
            tone: InlineMessageTone.success,
            message:
                'Thanks. You meet the ${AgeEligibility.minimumAge}+ '
                'requirement.',
          )
        else if (eligible == false)
          const InlineMessage(
            tone: InlineMessageTone.error,
            title: 'You need to be ${AgeEligibility.minimumAge} or older',
            message:
                'Social Dating is for adults only. If you continue, '
                'you won\'t be able to use the app.',
          ),
        if (failure != null) ...[
          AppSpacing.gapLg,
          FailureBanner(failure: failure, onRetry: _submit),
        ],
        AppSpacing.gapLg,
        Text(
          'We use your birth date only to check your age. It is not shown on '
          'your profile and is not saved on this device.',
          style: context.text.bodySmall?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ],
    );
  }
}
