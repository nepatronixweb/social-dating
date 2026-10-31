import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/auth_step_indicator.dart';
import '../../../core/widgets/brand_atmosphere.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/country.dart';
import '../providers/session_provider.dart';

/// Enter a phone number to receive a code.
///
/// After a correct code, a number already in the database opens Discover.
/// A new number continues to gender, then full name, then Discover.
///
/// Validation here is for UX only (catching typos early). A real backend
/// must validate numbers itself.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.login = false});

  final bool login;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'phone');

  Country _country = Country.nepal;
  bool _sending = false;
  bool _blurred = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text.isNotEmpty && !_blurred) {
        setState(() => _blurred = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? get _validation => _country.validateNational(_controller.text);
  bool get _isValid => _validation == null;

  /// Show a problem once the number is long enough to judge, or after the
  /// field was left. Never while someone is still typing a short number, and
  /// never for an empty field.
  String? get _visibleError {
    final problem = _validation;
    if (problem == null || _controller.text.isEmpty) return null;
    final digits = _country.nationalDigits(_controller.text);
    final longEnough = digits.length >= _country.minDigits;
    return (_blurred || longEnough) ? problem : null;
  }

  void _changeCountry(Country country) {
    final digits = PhoneNumberFormatter.digitsOf(_controller.text);
    final text = PhoneNumberFormatter.format(
      digits,
      groups: country.groups,
      digitLimit: country.maxDigits + (country.hasTrunkZero ? 1 : 0),
      allowPlus: false,
    );
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _country = country;
      _failure = null;
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!_isValid) {
      setState(() => _blurred = true);
      return;
    }
    FocusScope.of(context).unfocus();

    final phone = _country.toE164(_controller.text);
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final registered = await ref.read(sessionProvider.notifier).sendCode(phone);
      if (!mounted) return;
      await context.push(
        AppRoutes.verifyWithPhone(phone, login: registered),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final canSend = _isValid;

    return AppPage(
      atmosphere: BrandAtmosphereStyle.waves,
      appBar: AppTopBar(
        title: widget.login ? 'Log in' : 'Create account',
        transparent: true,
        circleBack: true,
      ),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.xl,
        ),
        child: ConstrainedContent(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.borderPill,
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(
                    alpha: canSend ? 0.38 : 0.12,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AppButton(
              label: 'Send code',
              icon: AppIcons.send,
              pill: true,
              isLoading: _sending,
              onPressed: canSend ? _submit : null,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: widget.login ? null : const AuthStepIndicator(step: 1),
                title: widget.login ? 'Welcome back' : 'What\'s your',
                accentTitle: widget.login ? null : 'number?',
                subtitle: widget.login
                    ? 'If this number is already registered, a code takes you '
                          'to Discover. If it is new, a code then gender and '
                          'name.'
                    : 'Used to sign in. We will send a code to this number.',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                  AppSpacing.pageGutter,
                  AppSpacing.xl,
                ),
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: PhoneNumberField(
                  country: _country,
                  onCountryChanged: _changeCountry,
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_sending,
                  errorText: _visibleError,
                  onChanged: (_) => setState(() => _failure = null),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              if (failure != null)
                Padding(
                  padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.lg),
                  child: FailureBanner(failure: failure, onRetry: _submit),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
