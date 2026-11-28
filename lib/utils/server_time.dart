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

// PestRaksh: times are shown in India time whatever the phone's zone (APP_PLAN
// "Times"), as on the website: a customer in Dubai booking for parents in
// Bengaluru must see "10:00 AM", not 8:30 AM. The two helpers below are for
// showing times only; compare, sort and count down on the instants that
// [parseServerTime] returns.

/// True for a bare date such as "2026-11-27" (a booking date): a calendar day,
/// shown as that day on every phone and never moved to another zone.
bool isServerDateOnly(String? raw) =>
    raw != null && _kDateOnly.hasMatch(raw.trim());

/// The India wall-clock time of [instant], for formatting only.
///
/// The result's year, month, day, hour and minute are what a clock in India
/// shows at that instant (UTC + 5:30; India has no daylight saving). It is
/// flagged UTC only so that no phone zone shifts it again; it is not the same
/// instant as [instant], so never compare it with [DateTime.now] or another
/// time.
DateTime toIndiaWallClock(DateTime instant) =>
    instant.toUtc().add(kServerUtcOffset);
