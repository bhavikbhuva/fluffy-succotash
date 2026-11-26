// PestRaksh: the booking dates and arrival windows from `available_slots`, the
// list the website's checkout picker uses (BookingDatePicker.tsx). Every rule
// (closed days, holidays, capacity, windows that already started, "today") is
// the backend's; the app only shows what it gets.
import 'package:customer/utils/json_parsers.dart';

/// One arrival window on one date, e.g. "09:00 AM - 11:00 AM".
class BookingSlot {
  BookingSlot.fromJson(Map<String, dynamic> json)
    : id = parseInt(json['id']) ?? 0,
      label = parseString(json['label']) ?? '',
      startTime = parseString(json['start_time']) ?? '',
      endTime = parseString(json['end_time']) ?? '',
      remainingCapacity = parseInt(json['remaining_capacity']) ?? 0,
      isPassedToday = parseBool(json['is_passed_today']) ?? false,
      isAvailable = parseBool(json['is_available']) ?? false;

  final int id;
  final String label;
  final String startTime;
  final String endTime;
  final int remainingCapacity;

  /// Started already, or starts too soon to book today.
  final bool isPassedToday;
  final bool isAvailable;

  /// The label, or "start - end" when the office left it empty.
  String get displayLabel =>
      label.isNotEmpty ? label : '$startTime - $endTime';
}

/// One day of the date strip.
class BookingSlotDate {
  BookingSlotDate.fromJson(Map<String, dynamic> json)
    : date = parseString(json['date']) ?? '',
      isToday = parseBool(json['is_today']) ?? false,
      isBlackout = parseBool(json['is_blackout']) ?? false,
      isDayOff = parseBool(json['is_day_off']) ?? false,
      isAvailable = parseBool(json['is_available']) ?? false,
      slots = [
        for (final s in (json['slots'] is List ? json['slots'] as List : const []))
          if (s is Map<String, dynamic>) BookingSlot.fromJson(s),
      ];

  /// "YYYY-MM-DD", sent back as `booking_date`.
  final String date;

  /// From the server's clock (India time), not the phone's.
  final bool isToday;

  /// A holiday set in the admin.
  final bool isBlackout;

  /// A closed weekday.
  final bool isDayOff;

  /// At least one window can still be booked.
  final bool isAvailable;
  final List<BookingSlot> slots;

  /// The calendar day, without any time zone.
  DateTime? get day {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  BookingSlot? slotById(int? id) {
    if (id == null) return null;
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }
}
