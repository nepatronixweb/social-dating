import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/onboarding_page.dart';

/// Second setup step for a new number: full name, then Discover.
class SignupNameScreen extends ConsumerStatefulWidget {
  const SignupNameScreen({super.key});

  @override
  ConsumerState<SignupNameScreen> createState() => _SignupNameScreenState();
}

class _SignupNameScreenState extends ConsumerState<SignupNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final gender = ref.read(sessionProvider).gender;
      await ref
          .read(sessionProvider.notifier)
          .completeProfile(
            displayName: _name.text.trim(),
            gender: gender?.name,
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

    return OnboardingPage(
      step: 2,
      total: 2,
      stepLabel: 'Name',
      title: 'What\'s your',
      accentTitle: 'name?',
      subtitle: 'This is shown on your profile.',
      primaryAction: AppButton(
        label: 'Continue',
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
          child: AppTextField(
            label: 'Full name',
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            validator: Validators.displayName,
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (failure != null) ...[
          FailureBanner(failure: failure, onRetry: _submit),
        ],
      ],
    );
  }
}
