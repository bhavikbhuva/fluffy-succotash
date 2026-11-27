// PestRaksh: Call and WhatsApp to the support number (Admin → Settings →
// Support Number), as the website (utils/whatsapp.ts; "Call us" in support
// chat, "WhatsApp us" on the booking page). Free click-to-chat: WhatsApp opens
// with a ready message; nothing is sent by itself.
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:url_launcher/url_launcher.dart';

/// Digits only, country code first; a bare 10-digit Indian number gets 91 in
/// front. '' when there is no usable number.
String supportDialNumber(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length == 10 ? '91$digits' : digits;
}

/// The support number from the stored settings, as [supportDialNumber].
String currentSupportNumber() =>
    supportDialNumber(SettingsHiveBox.instance.getAppSettings()?.supportNumber);

/// The wa.me link with [text] filled in, or null without a number.
Uri? whatsAppUri(String number, String text) => number.isEmpty
    ? null
    : Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');

/// Opens the phone's dialer on the support number.
Future<void> callSupport() async {
  final n = currentSupportNumber();
  if (n.isEmpty) return;
  await launchUrl(Uri.parse('tel:+$n')).catchError((_) => false);
}

/// Opens WhatsApp to the support number with [text] filled in.
Future<void> whatsAppSupport(String text) async {
  final uri = whatsAppUri(currentSupportNumber(), text);
  if (uri == null) return;
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
}
