import 'package:flutter/services.dart';

/// Locale-neutral phone formatting for passwordless sign-in.
///
/// Digits are grouped by [groups] (3-3-4-5 by default, e.g. `555 123 4567`)
/// and separated by spaces. When [allowPlus] is true a leading `+` is kept for
/// international numbers. At most [digitLimit] digits are accepted (15 by
/// default, the E.164 maximum).
///
/// Country-aware instances come from `Country.formatter`. Grouping is for
/// readability only; full numbering-plan rules belong with the backend.
class PhoneNumberFormatter extends TextInputFormatter {
  const PhoneNumberFormatter({
    this.groups = defaultGroups,
    this.digitLimit = maxDigits,
    this.allowPlus = true,
  });

  static const int maxDigits = 15;
  static const List<int> defaultGroups = [3, 3, 4, 5];

  final List<int> groups;
  final int digitLimit;
  final bool allowPlus;

  static String digitsOf(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// `+` followed by digits, or just digits when no `+` was typed.
  static String normalize(String input) {
    final digits = digitsOf(input);
    return input.trimLeft().startsWith('+') ? '+$digits' : digits;
  }

  static String format(
    String input, {
    List<int> groups = defaultGroups,
    int digitLimit = maxDigits,
    bool allowPlus = true,
  }) {
    final hasPlus = allowPlus && input.trimLeft().startsWith('+');
    var digits = digitsOf(input);
    if (digits.length > digitLimit) digits = digits.substring(0, digitLimit);

    final parts = <String>[];
    var index = 0;
    for (final size in groups) {
      if (index >= digits.length) break;
      final end = (index + size).clamp(0, digits.length);
      parts.add(digits.substring(index, end));
      index = end;
    }
    // Digits beyond the last group stay together rather than being dropped.
    if (index < digits.length) parts.add(digits.substring(index));
    return '${hasPlus ? '+' : ''}${parts.join(' ')}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(
      newValue.text,
      groups: groups,
      digitLimit: digitLimit,
      allowPlus: allowPlus,
    );

    // Keep the caret after the same number of digits it was after before.
    final extent = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCaret = digitsOf(
      newValue.text.substring(0, extent),
    ).length.clamp(0, digitLimit);

    var offset = formatted.startsWith('+') ? 1 : 0;
    if (digitsBeforeCaret > 0) {
      var seen = 0;
      offset = formatted.length;
      for (var i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) {
          seen++;
          if (seen == digitsBeforeCaret) {
            offset = i + 1;
            break;
          }
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
