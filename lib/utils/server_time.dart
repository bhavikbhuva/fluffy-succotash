// PestRaksh: the backend runs in India time (Asia/Kolkata, database +05:30) since
// 25 Nov 2026. A plain "YYYY-MM-DD HH:mm:ss" from the API is India time; the vendor
// app read it as UTC and showed every time 5½ hours late. One rule for the whole
// app, used by AppDateFormatter, the chat models and the maintenance notice.

/// India's offset from UTC. India has no daylight saving, so it never changes.
const Duration kServerUtcOffset = Duration(hours: 5, minutes: 30);

final RegExp _kTzSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');
final RegExp _kDateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses a date or time sent by the API and returns it in the phone's local
/// time. Returns null when [raw] is empty or not a date.
///
/// - With "Z" or an offset ("2026-11-26T04:30:00.000000Z"): read as it says.
/// - A bare date ("2026-11-27", a booking date): that calendar day, not shifted,
///   so it is the same day on every phone.
/// - A plain date and time ("2026-11-26 10:00:00"): India time.
DateTime? parseServerTime(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty || s == 'null') return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  if (_kTzSuffix.hasMatch(s)) return parsed.toLocal();
  if (_kDateOnly.hasMatch(s)) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
  ).subtract(kServerUtcOffset).toLocal();
}
