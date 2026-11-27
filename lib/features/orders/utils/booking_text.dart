// PestRaksh: how bookings are worded, as on the website (utils/bookingText.ts).
import 'package:customer/features/orders/models/order_model.dart';
import 'package:intl/intl.dart';

/// "Fri, 27 Nov 2026" for "2026-11-27". The calendar day as booked, on any
/// phone; anything unreadable comes back as it was.
String bookingVisitDate(String? date) {
  final raw = (date ?? '').trim();
  if (raw.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (m == null) return raw;
  final day = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return DateFormat('EEE, d MMM y').format(day);
}

/// "Fri, 27 Nov 2026 · 09:00 AM - 11:00 AM"; either part may be missing.
String bookingAppointmentText(String? date, String? window) => [
  bookingVisitDate(date),
  (window ?? '').trim(),
].where((s) => s.isNotEmpty).join(' · ');

/// The title of a booking line: its service ("Cockroach Control"), or the
/// package it was booked as when the service has since been deleted.
String bookingLineTitle(OrderItems item) {
  final service = (item.serviceName ?? '').trim();
  if (service.isNotEmpty) return service;
  final package = (item.productName ?? '').trim();
  return package.isNotEmpty ? package : (item.name ?? '').trim();
}

/// The package under the title ("2 BHK (Single Service)"), or '' when the
/// title already is the package.
String bookingLinePackage(OrderItems item) {
  final package = (item.productName ?? '').trim();
  return package == bookingLineTitle(item) ? '' : package;
}

/// The technician to show on a booking: only while one is on the job or has
/// done it (Technician assigned, on the way, Service completed) and the
/// booking isn't a pickup, as on the website (OrderDetail.tsx). A cancelled
/// booking keeps its technician's id, so the name alone isn't enough.
String bookingTechnicianName(OrderData order) {
  const shown = {9, 5, 6};
  if (!shown.contains(order.activeStatus)) return '';
  if (order.deliveryType == 'pickup') return '';
  return (order.deliveryBoyName ?? '').trim();
}
