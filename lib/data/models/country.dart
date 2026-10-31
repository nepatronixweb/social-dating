import 'package:flutter/foundation.dart';

import '../../core/utils/phone_formatter.dart';

/// A calling country for phone entry. Rules are deliberately simple (digit
/// count and a mobile prefix pattern) and exist for UX only: a real backend or
/// numbering-plan library must validate numbers authoritatively.
@immutable
class Country {
  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
    required this.example,
    this.groups = const [3, 3, 4],
    this.mobilePattern,
    this.patternMessage,
    this.hasTrunkZero = false,
  });

  /// ISO 3166-1 alpha-2 code, also used as a text badge (no flag emoji).
  final String isoCode;
  final String name;

  /// With the leading plus, e.g. `+977`.
  final String dialCode;

  /// Digit counts of the national number, without any trunk `0`.
  final int minDigits;
  final int maxDigits;

  /// A sample national number shown as the hint.
  final String example;

  /// Visual grouping of the national number.
  final List<int> groups;

  /// Regular expression a valid national mobile number must match.
  final String? mobilePattern;
  final String? patternMessage;

  /// Numbers are often written with a leading `0` that is dropped
  /// internationally (e.g. the UK).
  final bool hasTrunkZero;

  /// The national digits, with a trunk zero removed where the country has one.
  String nationalDigits(String input) {
    var digits = PhoneNumberFormatter.digitsOf(input);
    if (hasTrunkZero && digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  /// A UX-only check. Returns a message or `null` when the number looks valid.
  String? validateNational(String? input) {
    final digits = nationalDigits(input ?? '');
    if (digits.isEmpty) return 'Enter your phone number';
    if (digits.length < minDigits) return 'That number looks too short';
    if (digits.length > maxDigits) return 'That number looks too long';
    final pattern = mobilePattern;
    if (pattern != null && !RegExp(pattern).hasMatch(digits)) {
      return patternMessage ?? 'Enter a valid $name mobile number';
    }
    return null;
  }

  /// `+9779841234567`
  String toE164(String input) => '$dialCode${nationalDigits(input)}';

  /// A formatter for this country's national numbers.
  PhoneNumberFormatter get formatter => PhoneNumberFormatter(
    groups: groups,
    digitLimit: maxDigits + (hasTrunkZero ? 1 : 0),
    allowPlus: false,
  );

  @override
  bool operator ==(Object other) =>
      other is Country && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;

  // ---------------------------------------------------------------------------

  static const Country nepal = Country(
    isoCode: 'NP',
    name: 'Nepal',
    dialCode: '+977',
    minDigits: 10,
    maxDigits: 10,
    example: '984 123 4567',
    mobilePattern: r'^9[678]\d{8}$',
    patternMessage: 'Nepal mobile numbers start with 96, 97 or 98',
  );

  static const List<Country> all = [
    nepal,
    Country(
      isoCode: 'IN',
      name: 'India',
      dialCode: '+91',
      minDigits: 10,
      maxDigits: 10,
      example: '98765 43210',
      groups: [5, 5],
      mobilePattern: r'^[6-9]\d{9}$',
      patternMessage: 'Indian mobile numbers start with 6, 7, 8 or 9',
    ),
    Country(
      isoCode: 'BD',
      name: 'Bangladesh',
      dialCode: '+880',
      minDigits: 10,
      maxDigits: 10,
      example: '1712 345678',
      groups: [4, 6],
      mobilePattern: r'^1[3-9]\d{8}$',
      patternMessage: 'Bangladeshi mobile numbers start with 13 to 19',
    ),
    Country(
      isoCode: 'US',
      name: 'United States',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10,
      example: '415 555 0132',
      mobilePattern: r'^[2-9]\d{9}$',
      patternMessage: 'US numbers don\'t start with 0 or 1',
    ),
    Country(
      isoCode: 'CA',
      name: 'Canada',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10,
      example: '416 555 0132',
      mobilePattern: r'^[2-9]\d{9}$',
      patternMessage: 'Canadian numbers don\'t start with 0 or 1',
    ),
    Country(
      isoCode: 'GB',
      name: 'United Kingdom',
      dialCode: '+44',
      minDigits: 10,
      maxDigits: 10,
      example: '7400 123456',
      groups: [4, 6],
      mobilePattern: r'^7\d{9}$',
      patternMessage: 'UK mobile numbers start with 07',
      hasTrunkZero: true,
    ),
    Country(
      isoCode: 'AU',
      name: 'Australia',
      dialCode: '+61',
      minDigits: 9,
      maxDigits: 9,
      example: '412 345 678',
      groups: [3, 3, 3],
      mobilePattern: r'^4\d{8}$',
      patternMessage: 'Australian mobile numbers start with 04',
      hasTrunkZero: true,
    ),
    Country(
      isoCode: 'AE',
      name: 'United Arab Emirates',
      dialCode: '+971',
      minDigits: 9,
      maxDigits: 9,
      example: '50 123 4567',
      groups: [2, 3, 4],
      mobilePattern: r'^5\d{8}$',
      patternMessage: 'UAE mobile numbers start with 5',
    ),
    Country(
      isoCode: 'QA',
      name: 'Qatar',
      dialCode: '+974',
      minDigits: 8,
      maxDigits: 8,
      example: '3312 3456',
      groups: [4, 4],
      mobilePattern: r'^[3567]\d{7}$',
      patternMessage: 'Qatari mobile numbers start with 3, 5, 6 or 7',
    ),
    Country(
      isoCode: 'MY',
      name: 'Malaysia',
      dialCode: '+60',
      minDigits: 9,
      maxDigits: 10,
      example: '12 345 6789',
      groups: [2, 3, 5],
      mobilePattern: r'^1\d{8,9}$',
      patternMessage: 'Malaysian mobile numbers start with 1',
    ),
    Country(
      isoCode: 'SG',
      name: 'Singapore',
      dialCode: '+65',
      minDigits: 8,
      maxDigits: 8,
      example: '8123 4567',
      groups: [4, 4],
      mobilePattern: r'^[89]\d{7}$',
      patternMessage: 'Singapore mobile numbers start with 8 or 9',
    ),
  ];

  /// The country whose dial code starts [e164] (longest code wins).
  static Country? forE164(String e164) {
    Country? best;
    for (final country in all) {
      if (e164.startsWith(country.dialCode) &&
          (best == null || country.dialCode.length > best.dialCode.length)) {
        best = country;
      }
    }
    return best;
  }

  /// `+977 984 123 4567` for display.
  static String display(String e164) {
    final country = forE164(e164);
    if (country == null) return e164;
    final national = e164.substring(country.dialCode.length);
    return '${country.dialCode} '
        '${PhoneNumberFormatter.format(national, groups: country.groups, allowPlus: false)}';
  }

  /// `+977 ••••••4567`: safe to show and to persist.
  static String mask(String e164) {
    final country = forE164(e164);
    final dial = country?.dialCode ?? '+';
    final national = e164.substring(dial.length);
    if (national.length <= 4) return '$dial ••••';
    final hidden = '•' * (national.length - 4);
    return '$dial $hidden${national.substring(national.length - 4)}';
  }
}
