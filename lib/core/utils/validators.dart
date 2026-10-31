import 'phone_formatter.dart';

/// Form validators. Each returns an error message, or `null` when valid, so
/// they plug straight into `TextFormField.validator`.
///
/// These are UX conveniences only. Real validation must also happen on the
/// server.
abstract final class Validators {
  static const int minAge = 18;
  static const int maxAge = 99;
  static const int verificationCodeLength = 6;
  static const int maxBioLength = 300;

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number';
    }
    final digits = PhoneNumberFormatter.digitsOf(value).length;
    if (digits < 7) return 'That number looks too short';
    if (digits > PhoneNumberFormatter.maxDigits) {
      return 'That number looks too long';
    }
    return null;
  }

  static String? verificationCode(String? value) {
    final digits = PhoneNumberFormatter.digitsOf(value ?? '');
    if (digits.isEmpty) return 'Enter the 6-digit code';
    if (digits.length != verificationCodeLength) {
      return 'The code has $verificationCodeLength digits';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 2) return 'Use at least 2 characters';
    if (v.length > 30) return 'Keep it under 30 characters';
    if (!RegExp(r"^[\p{L}][\p{L}\s'.-]*$", unicode: true).hasMatch(v)) {
      return 'Use letters only';
    }
    return null;
  }

  static String? age(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your age';
    final age = int.tryParse(v);
    if (age == null) return 'Enter a number';
    if (age < minAge) return 'You must be $minAge or older';
    if (age > maxAge) return 'Enter a valid age';
    return null;
  }

  static String? bio(String? value) {
    if ((value?.length ?? 0) > maxBioLength) {
      return 'Keep your bio under $maxBioLength characters';
    }
    return null;
  }
}
