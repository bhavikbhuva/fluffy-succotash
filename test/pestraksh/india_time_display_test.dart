// PestRaksh: times are shown in India time whatever the phone's zone (APP_PLAN
// "Times"). Run this file under several zones, e.g.
// `TZ=America/New_York flutter test test/pestraksh/india_time_display_test.dart`;
// every expectation is the same in every zone.
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/server_time.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  setUpAll(() async {
    // The formatter reads the admin's date and time formats from the settings
    // box; an empty box gives the defaults "d/m/Y" and "h:i A".
    await HiveTestHelper.setUp(settingsBox);
    debugPrint('Phone zone: ${DateTime.now().timeZoneName}');
  });

  tearDownAll(() => HiveTestHelper.tearDown(settingsBox));

  group('shown in India time', () {
    test('a plain server time shows as written', () {
      const raw = '2026-11-27 10:00:00';
      expect(AppDateFormatter.formatTime(raw), '10:00 AM');
      expect(AppDateFormatter.formatDate(raw), '27/11/2026');
      expect(AppDateFormatter.formatDateTime(raw), '27/11/2026 10:00 AM');
    });

    test('the same instant with Z or an offset shows the same', () {
      expect(
        AppDateFormatter.formatDateTime('2026-11-27T04:30:00.000000Z'),
        '27/11/2026 10:00 AM',
      );
      expect(
        AppDateFormatter.formatDateTime('2026-11-27T10:00:00+05:30'),
        '27/11/2026 10:00 AM',
      );
    });

    test('a parsed instant passed as a DateTime shows the same', () {
      final instant = parseServerTime('2026-11-27 10:00:00')!;
      expect(AppDateFormatter.formatDateTime(instant), '27/11/2026 10:00 AM');
      expect(
        AppDateFormatter.formatDateTime(DateTime.utc(2026, 11, 27, 4, 30)),
        '27/11/2026 10:00 AM',
      );
    });

    test('an early-morning India time keeps its India date', () {
      // 27 Nov 02:00 in India is still 26 Nov in New York and in UTC.
      expect(
        AppDateFormatter.formatDateTime('2026-11-27 02:00:00'),
        '27/11/2026 02:00 AM',
      );
    });

    test('a late-evening India time keeps its India date', () {
      // 27 Nov 23:30 in India is already 28 Nov in Tokyo.
      expect(
        AppDateFormatter.formatDateTime('2026-11-27 23:30:00'),
        '27/11/2026 11:30 PM',
      );
    });

    test('a bare date stays its calendar day', () {
      expect(AppDateFormatter.formatDate('2026-11-27'), '27/11/2026');
    });

    test('unreadable input comes back as it was', () {
      expect(AppDateFormatter.formatDateTime('soon'), 'soon');
      expect(AppDateFormatter.formatDate(null), '');
    });
  });

  group('comparisons stay on true instants', () {
    test('parse gives the real instant, not India wall-clock fields', () {
      final parsed = AppDateFormatter.parse('2026-11-27 10:00:00')!;
      expect(parsed.toUtc(), DateTime.utc(2026, 11, 27, 4, 30));
      expect(parsed.isUtc, isFalse);
    });

    test('toIndiaWallClock is UTC + 5:30', () {
      final shown = toIndiaWallClock(DateTime.utc(2026, 11, 26, 20, 30));
      expect(
        [shown.year, shown.month, shown.day, shown.hour, shown.minute],
        [2026, 11, 27, 2, 0],
      );
    });

    test('isServerDateOnly spots bare dates only', () {
      expect(isServerDateOnly('2026-11-27'), isTrue);
      expect(isServerDateOnly(' 2026-11-27 '), isTrue);
      expect(isServerDateOnly('2026-11-27 10:00:00'), isFalse);
      expect(isServerDateOnly(null), isFalse);
    });
  });
}
