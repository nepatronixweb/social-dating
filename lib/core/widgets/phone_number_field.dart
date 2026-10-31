import 'package:flutter/material.dart';

import '../../data/models/country.dart';
import 'app_text_field.dart';
import 'country_selector.dart';

/// Phone number input for passwordless sign-in: a country selector (Nepal by
/// default in the screens that use it) followed by the national number, which
/// is grouped as the person types.
///
/// Validation messages come from the parent (see `Country.validateNational`),
/// so it can decide when an error is worth showing: not while someone is still
/// part-way through typing a number.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.country,
    required this.onCountryChanged,
    this.controller,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.pill = true,
  });

  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Rounded cinematic field used on branded auth. Settings can pass false.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Phone number',
      hint: 'Phone number',
      helper: 'Enter your number without the country code.',
      controller: controller,
      focusNode: focusNode,
      errorText: errorText,
      enabled: enabled,
      pill: pill,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [country.formatter],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefix: CountrySelectorButton(
        country: country,
        onChanged: onCountryChanged,
        enabled: enabled,
      ),
    );
  }
}
