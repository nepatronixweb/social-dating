import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/utils/age.dart';
import 'package:social_dating/core/utils/phone_formatter.dart';
import 'package:social_dating/data/models/account_state.dart';
import 'package:social_dating/data/models/country.dart';
import 'package:social_dating/data/models/session_snapshot.dart';

void main() {
  group('Country phone validation (UX only)', () {
    const nepal = Country.nepal;

    test('Nepal is the default: +977, ten digits', () {
      expect(nepal.dialCode, '+977');
      expect(nepal.isoCode, 'NP');
      expect(Country.all.first, nepal);
    });

    test('accepts valid Nepal mobile numbers in any formatting', () {
      for (final input in [
        '9841234567',
        '984 123 4567',
        '984-123-4567',
        '9612345678',
        '9712345678',
      ]) {
        expect(nepal.validateNational(input), isNull, reason: input);
      }
    });

    test('rejects empty, short, long and wrongly-prefixed numbers', () {
      expect(nepal.validateNational(''), 'Enter your phone number');
      expect(nepal.validateNational(null), 'Enter your phone number');
      expect(nepal.validateNational('98412'), 'That number looks too short');
      expect(
        nepal.validateNational('98412345678'),
        'That number looks too long',
      );
      expect(
        nepal.validateNational('1234567890'),
        'Nepal mobile numbers start with 96, 97 or 98',
      );
      expect(
        nepal.validateNational('9512345678'),
        'Nepal mobile numbers start with 96, 97 or 98',
      );
    });

    test('builds an E.164 number', () {
      expect(nepal.toE164('984 123 4567'), '+9779841234567');
    });

    test('drops a UK-style trunk zero', () {
      final uk = Country.all.firstWhere((c) => c.isoCode == 'GB');
      expect(uk.toE164('07911 123456'), '+447911123456');
      expect(uk.validateNational('07911 123456'), isNull);
    });

    test('every country has an example that passes its own rules', () {
      for (final country in Country.all) {
        expect(
          country.validateNational(country.example),
          isNull,
          reason: country.name,
        );
      }
    });

    test('displays and masks a number', () {
      expect(Country.display('+9779841234567'), '+977 984 123 4567');
      final masked = Country.mask('+9779841234567');
      expect(masked, startsWith('+977 '));
      expect(masked, endsWith('4567'));
      expect(masked, isNot(contains('984')));
    });

    test('finds the country for an E.164 number', () {
      expect(Country.forE164('+9779841234567'), Country.nepal);
      expect(Country.forE164('+919876543210')?.isoCode, 'IN');
      expect(Country.forE164('12345'), isNull);
    });
  });

  group('PhoneNumberFormatter with country groups', () {
    test('formats Nepal numbers 3-3-4 and limits to ten digits', () {
      final formatter = Country.nepal.formatter;
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '98412345678999'),
      );
      expect(result.text, '984 123 4567');
    });

    test('an Indian number uses 5-5 grouping', () {
      expect(
        PhoneNumberFormatter.format('9876543210', groups: [5, 5]),
        '98765 43210',
      );
    });
  });

  group('AgeEligibility', () {
    final today = DateTime(2026, 10, 14);

    test('computes age around the birthday', () {
      expect(AgeEligibility.ageOn(DateTime(2008, 10, 14), today), 18);
      expect(AgeEligibility.ageOn(DateTime(2008, 10, 15), today), 17);
      expect(AgeEligibility.ageOn(DateTime(2008, 10, 13), today), 18);
      expect(AgeEligibility.ageOn(DateTime(1990, 1, 1), today), 36);
    });

    test('18 is eligible on the birthday, 17 years 364 days is not', () {
      expect(AgeEligibility.isEligible(DateTime(2008, 10, 14), today), isTrue);
      expect(AgeEligibility.isEligible(DateTime(2008, 10, 15), today), isFalse);
    });

    test('handles a 29 February birthday', () {
      // Born 2008-02-29: turns 18 on 2026-02-28 or 03-01 depending on rule,
      // but by October 2026 they are certainly 18.
      expect(AgeEligibility.isEligible(DateTime(2008, 2, 29), today), isTrue);
    });
  });

  group('BirthDateParser', () {
    final today = DateTime(2026, 10, 14);

    BirthDateParse parse(String d, String m, String y) =>
        BirthDateParser.parse(day: d, month: m, year: y, today: today);

    test('incomplete input is quiet, not an error', () {
      for (final input in [('', '', ''), ('14', '', ''), ('14', '10', '19')]) {
        final result = parse(input.$1, input.$2, input.$3);
        expect(result.isValid, isFalse);
        expect(result.issue, BirthDateIssue.incomplete);
        expect(result.message, isNull);
      }
    });

    test('a real date is valid', () {
      final result = parse('7', '3', '1995');
      expect(result.isValid, isTrue);
      expect(result.date, DateTime(1995, 3, 7));
      expect(result.message, isNull);
    });

    test('impossible dates are explained', () {
      for (final input in [
        ('31', '02', '1995'),
        ('29', '02', '2001'),
        ('00', '05', '1995'),
        ('15', '13', '1995'),
        ('32', '01', '1995'),
      ]) {
        final result = parse(input.$1, input.$2, input.$3);
        expect(result.issue, BirthDateIssue.notARealDate, reason: '$input');
        expect(result.message, isNotNull);
      }
    });

    test('a leap day is accepted in a leap year', () {
      expect(parse('29', '02', '2000').isValid, isTrue);
    });

    test('future and absurdly old dates are rejected', () {
      expect(parse('15', '10', '2026').issue, BirthDateIssue.inFuture);
      expect(parse('01', '01', '2030').issue, BirthDateIssue.inFuture);
      expect(parse('01', '01', '1850').issue, BirthDateIssue.tooOld);
      expect(parse('01', '01', '1900').issue, BirthDateIssue.tooOld);
      expect(parse('14', '10', '2026').isValid, isTrue);
    });

    test('a two-digit year is not guessed', () {
      expect(parse('14', '10', '95').issue, BirthDateIssue.incomplete);
    });
  });

  group('session snapshot', () {
    test('round-trips and holds only non-sensitive fields', () {
      final snapshot = SessionSnapshot(
        statusName: 'loggedIn',
        savedAt: DateTime.utc(2026, 10, 14, 12),
        phoneLabel: '+977 •••••• 4567',
        displayName: 'Sam',
        account: const AccountState(
          id: 'mock-account-1',
          termsAccepted: true,
          isAgeEligible: true,
          displayName: 'Sam',
        ),
      );

      final decoded = SessionSnapshot.decode(snapshot.encode())!;
      expect(decoded.statusName, 'loggedIn');
      expect(decoded.savedAt, snapshot.savedAt);
      expect(decoded.phoneLabel, snapshot.phoneLabel);
      expect(decoded.account, snapshot.account);

      // Exactly these fields, and nothing credential-like.
      final keys = (jsonDecode(snapshot.encode()) as Map).keys.toSet();
      expect(keys, {
        'v',
        'status',
        'savedAt',
        'phoneLabel',
        'displayName',
        'account',
      });
      expect(snapshot.encode(), isNot(contains('9841234567')));
    });

    test('tolerates missing and malformed data', () {
      expect(SessionSnapshot.decode(null), isNull);
      expect(SessionSnapshot.decode(''), isNull);
      expect(SessionSnapshot.decode('not json'), isNull);
      expect(SessionSnapshot.decode('[]'), isNull);
      expect(SessionSnapshot.decode('{"v":1}'), isNull);
    });
  });

  group('AccountState', () {
    test('a fresh account has accepted nothing', () {
      const account = AccountState(id: 'a');
      expect(account.termsAccepted, isFalse);
      expect(account.hasBirthDate, isFalse);
      expect(account.isAgeEligible, isNull);
    });

    test('json round trip', () {
      const account = AccountState(
        id: 'a',
        termsAccepted: true,
        isAgeEligible: false,
      );
      expect(AccountState.fromJson(account.toJson()), account);
      expect(account.toJson().keys, isNot(contains('birthDate')));
    });
  });
}
