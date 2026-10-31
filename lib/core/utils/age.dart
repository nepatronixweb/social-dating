/// Age eligibility rules. UX only: a real backend must enforce the minimum age
/// itself, because anything checked on the device can be bypassed.
abstract final class AgeEligibility {
  static const int minimumAge = 18;
  static const int maximumPlausibleAge = 120;

  /// Whole years between [birthDate] and [today] (birthdays count on the day).
  static int ageOn(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  static bool isEligible(DateTime birthDate, DateTime today) =>
      ageOn(birthDate, today) >= minimumAge;
}

enum BirthDateIssue { incomplete, notARealDate, inFuture, tooOld }

/// Result of parsing day/month/year text into a birth date.
class BirthDateParse {
  const BirthDateParse._({this.date, this.issue});

  const BirthDateParse.valid(DateTime date) : this._(date: date);
  const BirthDateParse.invalid(BirthDateIssue issue) : this._(issue: issue);

  final DateTime? date;
  final BirthDateIssue? issue;

  bool get isValid => date != null;

  /// A message to show the user, or `null` when there is nothing to say yet
  /// (the date is simply incomplete or valid).
  String? get message => switch (issue) {
    BirthDateIssue.notARealDate => 'That date doesn\'t exist. Check the day.',
    BirthDateIssue.inFuture => 'Your birth date can\'t be in the future.',
    BirthDateIssue.tooOld => 'Enter a valid birth year.',
    BirthDateIssue.incomplete || null => null,
  };
}

abstract final class BirthDateParser {
  static const int earliestYear = 1900;

  static BirthDateParse parse({
    required String day,
    required String month,
    required String year,
    required DateTime today,
  }) {
    final d = int.tryParse(day.trim());
    final m = int.tryParse(month.trim());
    final y = int.tryParse(year.trim());

    if (d == null || m == null || y == null || year.trim().length < 4) {
      return const BirthDateParse.invalid(BirthDateIssue.incomplete);
    }
    if (y < earliestYear) {
      return const BirthDateParse.invalid(BirthDateIssue.tooOld);
    }
    if (m < 1 || m > 12 || d < 1 || d > 31) {
      return const BirthDateParse.invalid(BirthDateIssue.notARealDate);
    }

    final date = DateTime(y, m, d);
    // DateTime rolls 31 Feb over to March; a real date round-trips unchanged.
    if (date.year != y || date.month != m || date.day != d) {
      return const BirthDateParse.invalid(BirthDateIssue.notARealDate);
    }

    final todayDate = DateTime(today.year, today.month, today.day);
    if (date.isAfter(todayDate)) {
      return const BirthDateParse.invalid(BirthDateIssue.inFuture);
    }
    if (AgeEligibility.ageOn(date, today) >
        AgeEligibility.maximumPlausibleAge) {
      return const BirthDateParse.invalid(BirthDateIssue.tooOld);
    }
    return BirthDateParse.valid(date);
  }
}
