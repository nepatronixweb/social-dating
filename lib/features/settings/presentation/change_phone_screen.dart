import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/country.dart';
import '../../auth/providers/session_provider.dart';

class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'change-phone');
  Country _country = Country.nepal;
  bool _blurred = false;
  bool _busy = false;

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
  bool get _isValid => _validation == null && _controller.text.isNotEmpty;

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
    setState(() => _country = country);
  }

  Future<void> _submit() async {
    if (_busy || !_isValid) {
      if (!_isValid) setState(() => _blurred = true);
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Update the number on this device?',
      message:
          'No SMS is sent. Only a masked label will be shown.',
      confirmLabel: 'Update number',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final e164 = _country.toE164(_controller.text);
    ref.read(sessionProvider.notifier).updatePhone(e164);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'The number on this device was updated.',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(sessionProvider).phoneLabel;

    return AppPage(
      appBar: const AppTopBar(title: 'Change phone number'),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Save on this device',
            isLoading: _busy,
            onPressed: _isValid && !_busy ? _submit : null,
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
                title: 'New number',
                subtitle: masked == null
                    ? 'Only a masked label is shown after you save.'
                    : 'Currently shown as $masked',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PhoneNumberField(
                      country: _country,
                      onCountryChanged: _changeCountry,
                      controller: _controller,
                      focusNode: _focusNode,
                      errorText: _visibleError,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
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
