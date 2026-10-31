/// Formats an amount held in integer paisa (1 NPR = 100 paisa) as
/// `NPR 1,250.50`. Money is never held in floating point.
String formatNpr(int paisa) {
  final negative = paisa < 0;
  final abs = paisa.abs();
  final rupees = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}NPR ${_groupDigits(rupees)}.$cents';
}

/// Formats loyalty points (`10 pts`). 100 points = NPR 1 in the mock.
String formatPoints(int points) {
  final negative = points < 0;
  final abs = points.abs();
  final unit = abs == 1 ? 'pt' : 'pts';
  return '${negative ? '-' : ''}${_groupDigits(abs)} $unit';
}

String _groupDigits(int value) {
  final digits = value.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return grouped.toString();
}
