/// Swipe quota and pricing rules, as the UI presents them.
///
/// MOCK BEHAVIOUR: these numbers describe what the client displays and what the
/// in-memory mock repository enforces. They are NOT authoritative. A server
/// must own swipe counting, the Nepal-day boundary, pricing and balances, and
/// must reject anything the client lets through.
abstract final class SwipeRules {
  /// Swipes allowed while the profile is still incomplete (the "explore first"
  /// preview). After these, the profile-completion gate is shown.
  static const int previewSwipes = 5;

  /// Free left/right swipes per Nepal calendar day for male accounts, counted
  /// after the profile is complete. Left and right swipes share this counter.
  static const int freeDailySwipesMale = 20;

  /// Price of each swipe beyond the free limit, in paisa (NPR 0.10).
  static const int extraSwipePricePaisa = 10;

  /// Daily promotional points granted to males without a paid subscription.
  /// 1 point = 1 paisa.
  static const int dailyFreePointsMale = 100;

  /// Super like, discovery message and rewind each cost this many points for
  /// males without a paid subscription. Credited to the admin wallet.
  static const int premiumActionPricePoints = 100;

  /// Nepal Standard Time is UTC+05:45 with no daylight saving.
  static const Duration nepalUtcOffset = Duration(hours: 5, minutes: 45);

  /// Human-readable name of the quota day boundary.
  static const String quotaTimeZoneLabel = 'Nepal time (UTC+5:45)';

  /// Short label shown wherever counting or pricing appears.
  static const String mockLabel = 'Mock';

  /// Explains that counting and prices are simulated on this device.
  static const String mockDisclosure =
      'Mock behaviour: swipe counting and prices are simulated on this device. '
      'The server will be authoritative later.';
}

/// The Nepal calendar date of [instant], as `YYYY-MM-DD`. Quota counters reset
/// when this value changes (midnight in Nepal), regardless of the device's own
/// time zone.
String nepalDayKey(DateTime instant) {
  final nepal = instant.toUtc().add(SwipeRules.nepalUtcOffset);
  final month = nepal.month.toString().padLeft(2, '0');
  final day = nepal.day.toString().padLeft(2, '0');
  return '${nepal.year.toString().padLeft(4, '0')}-$month-$day';
}

/// The next Nepal midnight after [instant], as a UTC instant.
DateTime nextNepalMidnight(DateTime instant) {
  final nepal = instant.toUtc().add(SwipeRules.nepalUtcOffset);
  final nextDay = DateTime.utc(nepal.year, nepal.month, nepal.day + 1);
  return nextDay.subtract(SwipeRules.nepalUtcOffset);
}
