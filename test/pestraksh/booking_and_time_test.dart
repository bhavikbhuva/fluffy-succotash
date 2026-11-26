// PestRaksh: India time and the booking slot list (APP_PLAN Phase 1).
import 'package:customer/features/checkout/cubit/booking_slots_cubit.dart';
import 'package:customer/features/checkout/models/booking_slots_model.dart';
import 'package:customer/utils/server_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two days of the live `available_slots` answer (26 Nov 2026, 15:56 India time):
/// today's windows have passed, tomorrow's are open.
const _liveDates = [
  {
    'date': '2026-11-26',
    'is_today': true,
    'is_blackout': false,
    'is_day_off': false,
    'is_available': false,
    'slots': [
      {
        'id': 37,
        'start_time': '09:00',
        'end_time': '11:00',
        'label': '09:00 AM - 11:00 AM',
        'remaining_capacity': 4,
        'is_passed_today': true,
        'is_available': false,
      },
    ],
  },
  {
    'date': '2026-11-27',
    'is_today': false,
    'is_blackout': false,
    'is_day_off': false,
    'is_available': true,
    'slots': [
      {
        'id': 41,
        'start_time': '09:00',
        'end_time': '11:00',
        'label': '09:00 AM - 11:00 AM',
        'remaining_capacity': 4,
        'is_passed_today': false,
        'is_available': true,
      },
      {
        'id': 42,
        'start_time': '11:00',
        'end_time': '13:00',
        'label': '',
        'remaining_capacity': 1,
        'is_passed_today': false,
        'is_available': true,
      },
    ],
  },
];

void main() {
  group('parseServerTime', () {
    test('a plain date and time is India time', () {
      expect(
        parseServerTime('2026-11-26 10:00:00')!.toUtc(),
        DateTime.utc(2026, 11, 26, 4, 30),
      );
    });

    test('a time with Z is read as UTC', () {
      expect(
        parseServerTime('2026-11-26T04:30:00.000000Z')!.toUtc(),
        DateTime.utc(2026, 11, 26, 4, 30),
      );
    });

    test('a time with an offset is read as it says', () {
      expect(
        parseServerTime('2026-11-26T10:00:00+05:30')!.toUtc(),
        DateTime.utc(2026, 11, 26, 4, 30),
      );
    });

    test('a bare date stays that calendar day', () {
      final d = parseServerTime('2026-11-27')!;
      expect([d.year, d.month, d.day, d.hour], [2026, 11, 27, 0]);
      expect(d.isUtc, isFalse);
    });

    test('empty or invalid gives null', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('null'), isNull);
      expect(parseServerTime('not a date'), isNull);
    });
  });

  group('BookingSlotDate', () {
    final dates = [for (final d in _liveDates) BookingSlotDate.fromJson(d)];

    test('parses the live answer', () {
      expect(dates.first.isToday, isTrue);
      expect(dates.first.isAvailable, isFalse);
      expect(dates.first.slots.single.isPassedToday, isTrue);
      expect(dates[1].day, DateTime(2026, 11, 27));
      expect(dates[1].slotById(41)!.displayLabel, '09:00 AM - 11:00 AM');
      expect(dates[1].slotById(99), isNull);
    });

    test('an empty label falls back to start - end', () {
      expect(dates[1].slotById(42)!.displayLabel, '11:00 - 13:00');
    });
  });

  group('BookingSlotsState', () {
    final dates = [for (final d in _liveDates) BookingSlotDate.fromJson(d)];

    test('complete only with an open date and an open window', () {
      expect(BookingSlotsState(dates: dates).isComplete, isFalse);
      expect(
        BookingSlotsState(dates: dates, selectedDate: '2026-11-27')
            .isComplete,
        isFalse,
      );
      expect(
        BookingSlotsState(
          dates: dates,
          selectedDate: '2026-11-27',
          selectedSlotId: 41,
        ).isComplete,
        isTrue,
      );
      // A window of another day does not count.
      expect(
        BookingSlotsState(
          dates: dates,
          selectedDate: '2026-11-26',
          selectedSlotId: 41,
        ).isComplete,
        isFalse,
      );
    });
  });
}
