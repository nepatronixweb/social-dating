import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/auth_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/auth_step_indicator.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/brand_atmosphere.dart';
import '../../../core/widgets/failure_banner.dart';
import '../../../core/widgets/otp_input.dart';
import '../../../core/widgets/resend_code_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/country.dart';
import '../providers/session_provider.dart';

/// Enter the one-time code.
///
/// Create-account continues into setup. [login] opens the app after a
/// valid code. This screen never navigates forward itself; the router does.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.phone, this.login = false});

  /// The number the code was sent to, in E.164 form.
  final String phone;
  final bool login;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  bool _verifying = false;
  AppFailure? _failure;
  bool _resendFailed = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _complete => _code.text.length == AppConstants.otpLength;
  bool get _expired => _failure is CodeExpiredFailure;

  /// Problems with the code itself appear on the boxes; everything else
  /// (network, generic failure) appears in a banner with a retry.
  String? get _codeError =>
      (_failure is InvalidCodeFailure || _failure is CodeExpiredFailure)
      ? _failure!.message
      : null;

  Future<void> _verify() async {
    if (_verifying || !_complete) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _verifying = true;
      _resendFailed = false;
      _failure = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .signInWithPhone(
            phone: widget.phone,
            code: _code.text,
            login: widget.login,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<bool> _resend() async {
    try {
      await ref.read(sessionProvider.notifier).sendCode(widget.phone);
      if (!mounted) return false;
      _code.clear();
      setState(() => _failure = null);
      showAppSnackBar(
        context,
        'A new code was requested.',
        type: AppSnackType.success,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _resendFailed = true;
        _failure = AppFailure.from(error);
      });
      return false;
    }
  }

  void _editPhone() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.phone(login: widget.login));
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final bannerFailure = _codeError == null ? failure : null;
    final canVerify = _complete;

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
                    alpha: canVerify ? 0.38 : 0.12,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AppButton(
              label: widget.login ? 'Log in' : 'Verify',
              icon: AppIcons.forward,
              iconOnEnd: true,
              pill: true,
              isLoading: _verifying,
              onPressed: canVerify ? _verify : null,
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
                eyebrow: widget.login ? null : const AuthStepIndicator(step: 2),
                title: 'Enter your',
                accentTitle: 'code',
                subtitle: widget.login
                    ? 'SMS is not sent yet. Enter ${AuthRules.developmentOtp} '
                          'for ${Country.display(widget.phone)}. '
                          'A correct code opens the app.'
                    : 'SMS is not sent yet. Enter ${AuthRules.developmentOtp} '
                          'for ${Country.display(widget.phone)}. '
                          'Then choose your gender and name.',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                  AppSpacing.pageGutter,
                  AppSpacing.xl,
                ),
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: OtpInput(
                  controller: _code,
                  enabled: !_verifying,
                  errorText: _codeError,
                  onChanged: (_) => setState(() => _failure = null),
                  onCompleted: (_) => _verify(),
                ),
              ),
              if (bannerFailure != null)
                Padding(
                  padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.lg),
                  child: FailureBanner(
                    failure: bannerFailure,
                    onRetry: _resendFailed
                        ? _resend
                        : (_complete ? _verify : null),
                  ),
                ),
              Padding(
                padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResendCodeButton(onResend: _resend, readyNow: _expired),
                    TextButton.icon(
                      onPressed: _verifying ? null : _editPhone,
                      icon: const Icon(AppIcons.refresh, size: AppSizes.iconSm),
                      label: const Text('Change number'),
                    ),
                  ],
                ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
