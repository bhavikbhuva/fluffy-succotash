// PestRaksh: the warranty line of a package, as on the website
// (services-frontend `serviceBadges.ts`, `warrantyLabel`). A service is booked,
// not shipped, so it has a warranty where the vendor's shop had "returns".
import 'package:customer/core/localization/language_label_key.dart';

/// "{days}-day warranty", or "{days}-day warranty, free re-visit" when the
/// package includes a free re-visit. Null when the package has no warranty
/// (days 0, negative or missing): nothing is shown then.
String? warrantyLabel(
  String Function(String key) translate, {
  required int? days,
  int? freeRevisits,
}) {
  final d = days ?? 0;
  if (d <= 0) return null;
  final key = (freeRevisits ?? 0) > 0
      ? LanguageLabelKeys.warrantyBadgeWithRevisit
      : LanguageLabelKeys.warrantyBadge;
  return translate(key).replaceAll('{days}', '$d');
}
