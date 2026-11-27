// PestRaksh: a follow-up visit still to come, from `booking_visits/upcoming`
// (visit 2 of a yearly plan, a warranty re-visit). As the website's
// UpcomingVisitCard.tsx.
import 'package:customer/utils/json_parsers.dart';

class UpcomingVisit {
  UpcomingVisit.fromJson(Map<String, dynamic> json)
    : id = parseInt(json['id']) ?? 0,
      orderId = parseInt(json['order_id']) ?? 0,
      orderNumber = parseString(json['order_number']) ?? '',
      visitNo = parseInt(json['visit_no']) ?? 0,
      visitsTotal = parseInt(json['visits_total']) ?? 1,
      kind = parseString(json['kind']) ?? '',
      status = parseString(json['status']) ?? '',
      dueDate = parseString(json['due_date']) ?? '',
      bookingDate = parseString(json['booking_date']) ?? '',
      bookingTimeLabel = parseString(json['booking_time_label']) ?? '',
      serviceName = parseString(json['service_name']) ?? '',
      productName = parseString(json['product_name']) ?? '',
      overdue = parseBool(json['overdue']) ?? false;

  final int id;
  final int orderId;
  final String orderNumber;
  final int visitNo;
  final int visitsTotal;

  /// "revisit" for a warranty re-visit; otherwise a planned visit.
  final String kind;

  /// "pending" (no time chosen yet) or "scheduled".
  final String status;

  /// "YYYY-MM-DD": when the visit is due.
  final String dueDate;

  /// "YYYY-MM-DD" and the window's label, once a time is chosen.
  final String bookingDate;
  final String bookingTimeLabel;

  final String serviceName;

  /// The package booked.
  final String productName;

  /// Due date passed with no time chosen.
  final bool overdue;

  bool get isRevisit => kind == 'revisit';
  bool get isScheduled => status == 'scheduled' && bookingDate.isNotEmpty;

  /// The service, or the package when the service was deleted.
  String get title =>
      serviceName.trim().isNotEmpty ? serviceName.trim() : productName.trim();

  /// The package under the title, or '' when the title already is it.
  String get package => productName.trim() == title ? '' : productName.trim();

  /// For "Visit {n} of {m}": never less than the visit's own number.
  int get visitsShownTotal => visitsTotal > visitNo ? visitsTotal : visitNo;
}
