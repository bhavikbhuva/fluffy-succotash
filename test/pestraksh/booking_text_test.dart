// PestRaksh: booking wording (visit date, appointment, line title and package)
// and the booking fields the customer bookings API adds (APP_PLAN Phase 2).
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/utils/booking_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// One booking as the customer bookings API returns it (`orders.*`), cut down
/// to the fields these tests read.
Map<String, dynamic> _liveOrder() => {
  'id': 118,
  'order_number': 'PR-118',
  'active_status': 1,
  'booking_date': '2026-11-27',
  'booking_time_label': '09:00 AM - 11:00 AM',
  'delivery_boy_name': 'Ravi Kumar',
  'items': [
    {
      'id': 201,
      'order_id': 118,
      'product_name': '2 BHK (Single Service)',
      'service_name': 'Cockroach Control',
      'quantity': 1,
      'price': '1499.00',
    },
  ],
};

OrderItems _line({String? service, String? package, String? name}) =>
    OrderItems.fromJson({
      'service_name': service,
      'product_name': package,
      'name': name,
    });

void main() {
  group('bookingVisitDate', () {
    test('a booking date reads as weekday, day, month and year', () {
      // 27 Nov 2026 is a Friday.
      expect(bookingVisitDate('2026-11-27'), 'Fri, 27 Nov 2026');
    });

    test('a single-digit day has no leading zero', () {
      expect(bookingVisitDate('2026-12-01'), 'Tue, 1 Dec 2026');
    });

    // The API sends booking_date as a plain "YYYY-MM-DD" (a DATE column cast
    // to date:Y-m-d); a time after it, in India time, keeps that day.
    test('a date with a time after it is still the same day', () {
      expect(bookingVisitDate('2026-11-27 00:00:00'), 'Fri, 27 Nov 2026');
      expect(bookingVisitDate('2026-11-27T23:59:59+05:30'), 'Fri, 27 Nov 2026');
    });

    test('spaces around the date are ignored', () {
      expect(bookingVisitDate('  2026-11-27  '), 'Fri, 27 Nov 2026');
    });

    test('empty or null gives an empty text', () {
      expect(bookingVisitDate(null), '');
      expect(bookingVisitDate(''), '');
      expect(bookingVisitDate('   '), '');
    });

    test('unreadable text comes back as it was', () {
      expect(bookingVisitDate('tomorrow'), 'tomorrow');
      expect(bookingVisitDate('27/11/2026'), '27/11/2026');
    });
  });

  group('bookingAppointmentText', () {
    test('date and window are joined by a middle dot', () {
      expect(
        bookingAppointmentText('2026-11-27', '09:00 AM - 11:00 AM'),
        'Fri, 27 Nov 2026 · 09:00 AM - 11:00 AM',
      );
    });

    test('only the date when there is no window', () {
      expect(bookingAppointmentText('2026-11-27', null), 'Fri, 27 Nov 2026');
      expect(bookingAppointmentText('2026-11-27', ''), 'Fri, 27 Nov 2026');
    });

    test('only the window when there is no date', () {
      expect(
        bookingAppointmentText(null, '09:00 AM - 11:00 AM'),
        '09:00 AM - 11:00 AM',
      );
      expect(
        bookingAppointmentText('', '09:00 AM - 11:00 AM'),
        '09:00 AM - 11:00 AM',
      );
    });

    test('neither gives an empty text', () {
      expect(bookingAppointmentText(null, null), '');
      expect(bookingAppointmentText('', ''), '');
      expect(bookingAppointmentText('  ', '  '), '');
    });

    test('spaces around the window are trimmed', () {
      expect(
        bookingAppointmentText('2026-11-27', '  09:00 AM - 11:00 AM  '),
        'Fri, 27 Nov 2026 · 09:00 AM - 11:00 AM',
      );
    });
  });

  group('bookingLineTitle and bookingLinePackage', () {
    test('the service is the title and the package goes under it', () {
      final item = _line(
        service: 'Cockroach Control',
        package: '2 BHK (Single Service)',
      );
      expect(bookingLineTitle(item), 'Cockroach Control');
      expect(bookingLinePackage(item), '2 BHK (Single Service)');
    });

    test('a deleted service (empty name) makes the package the title', () {
      final item = _line(service: '', package: '2 BHK (Single Service)');
      expect(bookingLineTitle(item), '2 BHK (Single Service)');
      expect(bookingLinePackage(item), '');
    });

    test('a deleted service (null name) makes the package the title', () {
      final item = _line(service: null, package: '2 BHK (Single Service)');
      expect(bookingLineTitle(item), '2 BHK (Single Service)');
      expect(bookingLinePackage(item), '');
    });

    test('a service name of only spaces counts as missing', () {
      final item = _line(service: '   ', package: '2 BHK (Single Service)');
      expect(bookingLineTitle(item), '2 BHK (Single Service)');
      expect(bookingLinePackage(item), '');
    });

    test('a service named like its package shows no package line', () {
      final item = _line(
        service: 'General Pest Control',
        package: 'General Pest Control',
      );
      expect(bookingLineTitle(item), 'General Pest Control');
      expect(bookingLinePackage(item), '');
    });

    test('without a service or package the item name is the title', () {
      final item = _line(name: 'Termite Control');
      expect(bookingLineTitle(item), 'Termite Control');
      expect(bookingLinePackage(item), '');
    });
  });

  group('booking fields in the order model', () {
    test('OrderData.fromJson reads the booked visit and the technician', () {
      final order = OrderData.fromJson(_liveOrder());
      expect(order.bookingDate, '2026-11-27');
      expect(order.bookingTimeLabel, '09:00 AM - 11:00 AM');
      expect(order.deliveryBoyName, 'Ravi Kumar');
      expect(order.items, hasLength(1));
    });

    test('OrderItems.fromJson reads the service name', () {
      final order = OrderData.fromJson(_liveOrder());
      final item = order.items!.single;
      expect(item.serviceName, 'Cockroach Control');
      expect(item.productName, '2 BHK (Single Service)');
    });

    test('missing booking fields stay null', () {
      final order = OrderData.fromJson({
        'id': 1,
        'items': [
          {'id': 2, 'product_name': 'Old order'},
        ],
      });
      expect(order.bookingDate, isNull);
      expect(order.bookingTimeLabel, isNull);
      expect(order.deliveryBoyName, isNull);
      expect(order.items!.single.serviceName, isNull);
    });

    test('toJson writes the booking fields back', () {
      final json = OrderData.fromJson(_liveOrder()).toJson();
      expect(json['booking_date'], '2026-11-27');
      expect(json['booking_time_label'], '09:00 AM - 11:00 AM');
      expect(json['delivery_boy_name'], 'Ravi Kumar');
      final items = json['items'] as List;
      expect((items.single as Map)['service_name'], 'Cockroach Control');
    });

    test('a parsed booking gives the appointment and line wording', () {
      final order = OrderData.fromJson(_liveOrder());
      expect(
        bookingAppointmentText(order.bookingDate, order.bookingTimeLabel),
        'Fri, 27 Nov 2026 · 09:00 AM - 11:00 AM',
      );
      expect(bookingLineTitle(order.items!.single), 'Cockroach Control');
      expect(bookingLinePackage(order.items!.single), '2 BHK (Single Service)');
    });
  });
}
