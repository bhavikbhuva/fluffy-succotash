// PestRaksh: a booking's visits and warranty, from `GET booking_visits?order_id=`
// (backend Customer/BookingVisitsApiController::show), as the website's
// BookingVisitsCard.tsx shows them.
import 'package:customer/utils/json_parsers.dart';

/// One visit of a booked service: the first one, a planned follow-up, or a
/// warranty re-visit.
class BookingVisit {
  BookingVisit.fromJson(Map<String, dynamic> json)
    : id = parseInt(json['id']) ?? 0,
      visitNo = parseInt(json['visit_no']) ?? 0,
      kind = parseString(json['kind']) ?? '',
      status = parseString(json['status']) ?? '',
      dueDate = parseString(json['due_date']) ?? '',
      bookingDate = parseString(json['booking_date']) ?? '',
      bookingSlotId = parseInt(json['booking_slot_id']),
      bookingTimeLabel = parseString(json['booking_time_label']) ?? '',
      technicianName = parseString(json['technician_name']) ?? '',
      completedAt = parseString(json['completed_at']) ?? '',
      canSchedule = parseBool(json['can_schedule']) ?? false;

  final int id;
  final int visitNo;

  /// "revisit" for a warranty re-visit.
  final String kind;

  /// "pending", "scheduled", "completed" or "skipped".
  final String status;
  final String dueDate;
  final String bookingDate;
  final int? bookingSlotId;
  final String bookingTimeLabel;
  final String technicianName;
  final String completedAt;

  /// The customer may pick or change its time. False for a visit booked for
  /// today, which is already on the technician's round ("call us").
  final bool canSchedule;

  bool get isRevisit => kind == 'revisit';
  bool get isDone => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get isScheduled => status == 'scheduled' && bookingDate.isNotEmpty;
  bool get isOpen => status == 'pending' || status == 'scheduled';
}

/// The plan, warranty and free re-visits of one booked service.
class BookingVisitsSummary {
  BookingVisitsSummary.fromJson(Map<String, dynamic> json)
    : planVisits = parseInt(_plan(json)['visits']) ?? 1,
      warrantyDays = parseInt(_plan(json)['warranty_days']) ?? 0,
      freeRevisits = parseInt(_plan(json)['free_revisits']) ?? 0,
      workFinished = parseBool(json['work_finished']) ?? false,
      warrantyUntil = parseString(json['warranty_until']) ?? '',
      inWarranty = parseBool(json['in_warranty']) ?? false,
      revisitsLeft = parseInt(json['revisits_left']) ?? 0;

  static Map<String, dynamic> _plan(Map<String, dynamic> json) =>
      json['plan'] is Map<String, dynamic>
      ? json['plan'] as Map<String, dynamic>
      : const {};

  final int planVisits;
  final int warrantyDays;
  final int freeRevisits;
  final bool workFinished;

  /// "YYYY-MM-DD", or '' until the last visit is done.
  final String warrantyUntil;
  final bool inWarranty;
  final int revisitsLeft;
}

/// One service of the booking with its visits.
class BookingVisitsLine {
  BookingVisitsLine.fromJson(Map<String, dynamic> json)
    : orderItemId = parseInt(json['order_item_id']) ?? 0,
      productName = parseString(json['product_name']) ?? '',
      serviceName = parseString(json['service_name']) ?? '',
      branchId = parseInt(json['branch_id']) ?? 0,
      summary = BookingVisitsSummary.fromJson(
        json['summary'] is Map<String, dynamic>
            ? json['summary'] as Map<String, dynamic>
            : const {},
      ),
      visits = [
        for (final v
            in (json['visits'] is List ? json['visits'] as List : const []))
          if (v is Map<String, dynamic>) BookingVisit.fromJson(v),
      ],
      canRequestRevisit = parseBool(json['can_request_revisit']) ?? false,
      hasPlan = parseBool(json['has_plan']) ?? false;

  final int orderItemId;

  /// The package booked.
  final String productName;
  final String serviceName;

  /// For the time picker's `available_slots`.
  final int branchId;
  final BookingVisitsSummary summary;
  final List<BookingVisit> visits;
  final bool canRequestRevisit;

  /// False for an ordinary single visit with no warranty: nothing to show.
  final bool hasPlan;

  String get title =>
      serviceName.trim().isNotEmpty ? serviceName.trim() : productName.trim();
  String get package => productName.trim() == title ? '' : productName.trim();
}
