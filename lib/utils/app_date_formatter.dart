import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/utils/server_time.dart';
import 'package:intl/intl.dart';

/// PHP-style date/time token -> intl [DateFormat] pattern.
/// Covers the tokens the `settings/country_setting` api sends in
/// `date_format` / `time_format` (e.g. "d/m/Y", "h:i A", "d M Y", "H:i").
const Map<String, String> _kPhpToIntlTokens = {
  'd': 'dd',
  'j': 'd',
  'D': 'EEE',
  'l': 'EEEE',
  'm': 'MM',
  'n': 'M',
  'M': 'MMM',
  'F': 'MMMM',
  'Y': 'yyyy',
  'y': 'yy',
  'H': 'HH',
  'G': 'H',
  'h': 'hh',
  'g': 'h',
  'i': 'mm',
  's': 'ss',
  'A': 'a',
  'a': 'a',
};

/// Converts a PHP-style format string (e.g. "d/m/Y") to an intl [DateFormat]
/// pattern (e.g. "dd/MM/yyyy"). Unknown letters are escaped as literals so
/// they don't get misread as intl pattern symbols.
String _phpFormatToIntlPattern(String phpFormat) {
  final buffer = StringBuffer();
  for (final char in phpFormat.split('')) {
    final mapped = _kPhpToIntlTokens[char];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
      buffer.write("'$char'");
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Formats dates/times using the `date_format` / `time_format` strings the
/// `settings/country_setting` api returns (cached in [SettingsHiveBox] so
/// they survive across the session without refetching).
class AppDateFormatter {
  AppDateFormatter._();

  /// Parses an api date/time value (string or [DateTime]) to local time.
  /// PestRaksh: timezone-less wall-clock strings are India time, the server's
  /// zone (was: server UTC); see [parseServerTime]. Returns null if [input]
  /// can't be parsed. PestRaksh: this is the true instant, for comparing and
  /// counting down; the format methods below show it in India time.
  static DateTime? parse(dynamic input) => _parse(input);

  static DateTime? _parse(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input.isUtc ? input.toLocal() : input;
    if (input is String) {
      // PestRaksh: plain api times are India time (utils/server_time.dart).
      return parseServerTime(input);
    }
    return null;
  }

  /// PestRaksh: what a date or time looks like on screen: the India
  /// wall-clock fields of the instant, whatever the phone's zone (was: the
  /// phone's own zone, so a phone in Dubai showed a 10:00 AM booking as
  /// 8:30 AM). A bare date string ("2026-11-27") stays that calendar day.
  /// For showing only: [parse] still gives the true instant for comparing.
  /// A [DateTime] passed in is taken as an instant (as [parseServerTime] and
  /// [DateTime.now] give), not as a bare calendar day.
  static DateTime? _shown(dynamic input) {
    if (input is String && isServerDateOnly(input)) return _parse(input);
    final instant = _parse(input);
    return instant == null ? null : toIndiaWallClock(instant);
  }

  static String _formatDateFields(DateTime shown) {
    final pattern = _phpFormatToIntlPattern(
      SettingsHiveBox.instance.dateFormat,
    );
    return DateFormat(pattern).format(shown);
  }

  static String _formatTimeFields(DateTime shown) {
    final phpFormat = SettingsHiveBox.instance.timeFormat;
    final pattern = _phpFormatToIntlPattern(phpFormat);
    var formatted = DateFormat(pattern).format(shown);
    // PHP's lowercase "a" (am/pm) has no direct intl equivalent — intl's
    // "a" always yields upper-case AM/PM, so lower-case it back if requested.
    if (phpFormat.contains('a') && !phpFormat.contains('A')) {
      formatted = formatted.replaceAll('AM', 'am').replaceAll('PM', 'pm');
    }
    return formatted;
  }

  /// Formats [input] (a [DateTime] or api date string) using the stored
  /// `date_format`, in India time. Returns [input] as-is (stringified) if it
  /// can't be parsed.
  static String formatDate(dynamic input) {
    final shown = _shown(input);
    if (shown == null) return input?.toString() ?? '';
    return _formatDateFields(shown);
  }

  /// Formats [input] using the stored `time_format`, in India time.
  static String formatTime(dynamic input) {
    final shown = _shown(input);
    if (shown == null) return input?.toString() ?? '';
    return _formatTimeFields(shown);
  }

  /// Combines [formatDate] and [formatTime] — e.g. "15/01/2026 10:30 AM".
  static String formatDateTime(dynamic input) {
    // PestRaksh: converted to India time once and both halves formatted from
    // it (was: the date and time re-parsed separately).
    final shown = _shown(input);
    if (shown == null) return input?.toString() ?? '';
    return '${_formatDateFields(shown)} ${_formatTimeFields(shown)}';
  }
}
