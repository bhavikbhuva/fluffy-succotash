// PestRaksh: the "Visits & warranty" card of one booking, the data side: the
// line, visit and summary models, the repository's `booking_visits`,
// `booking_visits/schedule` and `booking_visits/revisit` calls, and the quiet
// cubit. The fixtures follow backend Customer/BookingVisitsApiController::show
// and BookingVisits::bookingLines / itemSummary.
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/orders/cubit/booking_visits_cubit.dart';
import 'package:customer/features/orders/models/booking_visits_model.dart';
import 'package:customer/features/orders/repositories/booking_visits_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visit 1 of a yearly plan, done by the technician. The server's status for a
/// done visit is "completed" (BookingVisits::COMPLETED).
const _visit1Done = {
  'id': 21,
  'visit_no': 1,
  'kind': 'planned',
  'due_date': '2026-08-25',
  'booking_date': '2026-08-25',
  'booking_slot_id': 3,
  'booking_time_label': '09:00 AM - 11:00 AM',
  'status': 'completed',
  'technician_name': 'Ravi Kumar',
  'completed_at': '2026-08-25 10:40:00',
  'can_schedule': false,
};

/// Visit 2: due, no time chosen yet.
const _visit2Pending = {
  'id': 22,
  'visit_no': 2,
  'kind': 'planned',
  'due_date': '2026-12-24',
  'booking_date': null,
  'booking_slot_id': null,
  'booking_time_label': null,
  'status': 'pending',
  'technician_name': null,
  'completed_at': null,
  'can_schedule': true,
};

/// Visit 3: further off, no time chosen yet.
const _visit3Pending = {
  'id': 23,
  'visit_no': 3,
  'kind': 'planned',
  'due_date': '2027-04-23',
  'booking_date': null,
  'booking_slot_id': null,
  'booking_time_label': null,
  'status': 'pending',
  'technician_name': null,
  'completed_at': null,
  'can_schedule': true,
};

/// A yearly plan of 3 visits, work not finished yet.
const _yearlyLine = {
  'order_item_id': 501,
  'product_name': '2 BHK - Yearly (3 visits)',
  'service_name': 'Cockroach Control',
  'option_name': '2 BHK',
  'branch_id': 4,
  'summary': {
    'plan': {'visits': 3, 'warranty_days': 0, 'free_revisits': 0},
    'booking_done_at': '2026-08-25 10:40:00',
    'work_finished': false,
    'warranty_until': null,
    'in_warranty': false,
    'revisits_used': 0,
    'revisits_left': 0,
  },
  'visits': [_visit1Done, _visit2Pending, _visit3Pending],
  'can_request_revisit': false,
  'has_plan': true,
};

/// A warranty re-visit booked with a date, a window and a technician.
const _scheduledRevisit = {
  'id': 31,
  'visit_no': 2,
  'kind': 'revisit',
  'due_date': '2026-11-30',
  'booking_date': '2026-12-01',
  'booking_slot_id': 5,
  'booking_time_label': '11:00 AM - 01:00 PM',
  'status': 'scheduled',
  'technician_name': 'Suresh B',
  'completed_at': null,
  'can_schedule': true,
};

/// A single visit with 90 days of warranty and 2 free re-visits, one used.
const _warrantyLine = {
  'order_item_id': 502,
  'product_name': '1 BHK',
  'service_name': 'Bed Bug Control',
  'option_name': '1 BHK',
  'branch_id': 4,
  'summary': {
    'plan': {'visits': 1, 'warranty_days': 90, 'free_revisits': 2},
    'booking_done_at': '2026-11-10 12:00:00',
    'work_finished': true,
    'warranty_until': '2027-02-08',
    'in_warranty': true,
    'revisits_used': 1,
    'revisits_left': 1,
  },
  'visits': [_scheduledRevisit],
  'can_request_revisit': true,
  'has_plan': true,
};

/// An ordinary single visit with no warranty: `has_plan` false.
const _plainLine = {
  'order_item_id': 503,
  'product_name': 'Kitchen',
  'service_name': 'General Pest Control',
  'option_name': 'Kitchen',
  'branch_id': 4,
  'summary': {
    'plan': {'visits': 1, 'warranty_days': 0, 'free_revisits': 0},
    'booking_done_at': null,
    'work_finished': false,
    'warranty_until': null,
    'in_warranty': false,
    'revisits_used': 0,
    'revisits_left': 0,
  },
  'visits': <dynamic>[],
  'can_request_revisit': false,
  'has_plan': false,
};

Map<String, dynamic> _answer(List<Object?> lines) => {
  'status': 1,
  'data': {'lines': lines, 'today': '2026-11-27'},
};

/// Never reached: the fake repositories below don't call the API. It keeps the
/// tests off the real ApiClient singleton.
class _UnusedApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the API is not used in this test');
}

/// Answers `get` and `post` with a fixed body, or throws [error], and keeps
/// what was sent.
class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.body, this.error});

  final Object? body;
  final Object? error;
  String? lastEndpoint;
  String? lastMethod;
  Map<String, dynamic>? lastQuery;
  Object? lastData;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? options,
    Object? cancelToken,
  }) async {
    lastMethod = 'GET';
    lastEndpoint = endpoint;
    lastQuery = queryParameters;
    if (error != null) throw error!;
    return body;
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Object? options,
    Object? cancelToken,
  }) async {
    lastMethod = 'POST';
    lastEndpoint = endpoint;
    lastQuery = queryParameters;
    lastData = data;
    if (error != null) throw error!;
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('only get and post are faked');
}

class _FakeRepository extends BookingVisitsRepository {
  _FakeRepository(this._answer) : super(apiClient: _UnusedApiClient());

  final Future<List<BookingVisitsLine>> Function() _answer;
  final List<String> orderIds = [];

  @override
  Future<List<BookingVisitsLine>> fetchForBooking(String orderId) {
    orderIds.add(orderId);
    return _answer();
  }
}

BookingVisitsLine _line(Map<String, dynamic> json) =>
    BookingVisitsLine.fromJson(json);

void main() {
  group('BookingVisitsLine.fromJson: a yearly plan', () {
    test('reads the line and its summary', () {
      final l = _line(Map.of(_yearlyLine));
      expect(l.orderItemId, 501);
      expect(l.productName, '2 BHK - Yearly (3 visits)');
      expect(l.serviceName, 'Cockroach Control');
      expect(l.branchId, 4);
      expect(l.hasPlan, isTrue);
      expect(l.canRequestRevisit, isFalse);
      expect(l.summary.planVisits, 3);
      expect(l.summary.warrantyDays, 0);
      expect(l.summary.freeRevisits, 0);
      expect(l.summary.workFinished, isFalse);
      expect(l.summary.warrantyUntil, '');
      expect(l.summary.inWarranty, isFalse);
      expect(l.summary.revisitsLeft, 0);
      expect(l.visits.map((v) => v.id), [21, 22, 23]);
      expect(l.visits.map((v) => v.visitNo), [1, 2, 3]);
    });

    test('visit 1, done, is closed and keeps its record', () {
      final v = _line(Map.of(_yearlyLine)).visits[0];
      expect(v.kind, 'planned');
      expect(v.isRevisit, isFalse);
      expect(v.isOpen, isFalse);
      expect(v.isSkipped, isFalse);
      expect(v.isScheduled, isFalse);
      expect(v.canSchedule, isFalse);
      expect(v.bookingDate, '2026-08-25');
      expect(v.bookingSlotId, 3);
      expect(v.bookingTimeLabel, '09:00 AM - 11:00 AM');
      expect(v.technicianName, 'Ravi Kumar');
      expect(v.completedAt, '2026-08-25 10:40:00');
    });

    // The server sends "completed" for a done visit (BookingVisits::COMPLETED,
    // and the website's BookingVisitsCard checks `status === "completed"`),
    // but the model's `isDone` checks for "done".
    test('visit 1, with the server\'s status "completed", reads done', () {
      final v = _line(Map.of(_yearlyLine)).visits[0];
      expect(v.status, 'completed');
      expect(v.isDone, isTrue);
    });

    test('visit 2 is pending with its due date and no time yet', () {
      final v = _line(Map.of(_yearlyLine)).visits[1];
      expect(v.status, 'pending');
      expect(v.dueDate, '2026-12-24');
      expect(v.bookingDate, '');
      expect(v.bookingSlotId, isNull);
      expect(v.bookingTimeLabel, '');
      expect(v.technicianName, '');
      expect(v.completedAt, '');
      expect(v.isOpen, isTrue);
      expect(v.isScheduled, isFalse);
      expect(v.isDone, isFalse);
      expect(v.isSkipped, isFalse);
      expect(v.isRevisit, isFalse);
      expect(v.canSchedule, isTrue);
    });

    test('visit 3 is pending too', () {
      final v = _line(Map.of(_yearlyLine)).visits[2];
      expect(v.status, 'pending');
      expect(v.dueDate, '2027-04-23');
      expect(v.isOpen, isTrue);
      expect(v.isScheduled, isFalse);
      expect(v.canSchedule, isTrue);
    });

    test('a skipped visit is skipped and closed', () {
      final v = BookingVisit.fromJson({
        ..._visit3Pending,
        'status': 'skipped',
        'can_schedule': false,
      });
      expect(v.isSkipped, isTrue);
      expect(v.isOpen, isFalse);
      expect(v.isDone, isFalse);
      expect(v.canSchedule, isFalse);
    });
  });

  group('BookingVisitsLine.fromJson: a warranty', () {
    test('work finished, in warranty, 1 re-visit left', () {
      final l = _line(Map.of(_warrantyLine));
      expect(l.orderItemId, 502);
      expect(l.hasPlan, isTrue);
      expect(l.canRequestRevisit, isTrue);
      expect(l.summary.planVisits, 1);
      expect(l.summary.warrantyDays, 90);
      expect(l.summary.freeRevisits, 2);
      expect(l.summary.workFinished, isTrue);
      expect(l.summary.warrantyUntil, '2027-02-08');
      expect(l.summary.inWarranty, isTrue);
      expect(l.summary.revisitsLeft, 1);
    });

    test('the scheduled re-visit has its date, window and technician', () {
      final v = _line(Map.of(_warrantyLine)).visits.single;
      expect(v.id, 31);
      expect(v.isRevisit, isTrue);
      expect(v.isScheduled, isTrue);
      expect(v.isOpen, isTrue);
      expect(v.isDone, isFalse);
      expect(v.canSchedule, isTrue);
      expect(v.dueDate, '2026-11-30');
      expect(v.bookingDate, '2026-12-01');
      expect(v.bookingSlotId, 5);
      expect(v.bookingTimeLabel, '11:00 AM - 01:00 PM');
      expect(v.technicianName, 'Suresh B');
      expect(v.completedAt, '');
    });

    test('a warranty that has run out, with no re-visits left', () {
      final l = _line({
        ..._warrantyLine,
        'summary': {
          'plan': {'visits': 1, 'warranty_days': 90, 'free_revisits': 2},
          'work_finished': true,
          'warranty_until': '2026-11-01',
          'in_warranty': false,
          'revisits_left': 0,
        },
        'can_request_revisit': false,
      });
      expect(l.summary.inWarranty, isFalse);
      expect(l.summary.warrantyUntil, '2026-11-01');
      expect(l.summary.revisitsLeft, 0);
      expect(l.canRequestRevisit, isFalse);
    });
  });

  group('BookingVisit.fromJson: booked for today', () {
    test('is scheduled and open but can no longer be moved', () {
      final v = BookingVisit.fromJson({
        ..._visit2Pending,
        'status': 'scheduled',
        'booking_date': '2026-11-27',
        'booking_slot_id': 2,
        'booking_time_label': '01:00 PM - 03:00 PM',
        'technician_name': 'Ravi Kumar',
        'can_schedule': false,
      });
      expect(v.isScheduled, isTrue);
      expect(v.isOpen, isTrue);
      expect(v.canSchedule, isFalse);
      expect(v.bookingDate, '2026-11-27');
      expect(v.bookingTimeLabel, '01:00 PM - 03:00 PM');
    });

    test('scheduled with no booking date is not scheduled, still open', () {
      for (final date in [null, '']) {
        final v = BookingVisit.fromJson({
          ..._scheduledRevisit,
          'booking_date': date,
        });
        expect(v.isScheduled, isFalse, reason: 'booking_date $date');
        expect(v.isOpen, isTrue, reason: 'booking_date $date');
      }
    });
  });

  group('safe defaults', () {
    test('an empty line has an empty summary and no visits', () {
      final l = _line(const {});
      expect(l.orderItemId, 0);
      expect(l.productName, '');
      expect(l.serviceName, '');
      expect(l.branchId, 0);
      expect(l.visits, isEmpty);
      expect(l.canRequestRevisit, isFalse);
      expect(l.hasPlan, isFalse);
      expect(l.title, '');
      expect(l.package, '');
      expect(l.summary.planVisits, 1);
      expect(l.summary.warrantyDays, 0);
      expect(l.summary.freeRevisits, 0);
      expect(l.summary.workFinished, isFalse);
      expect(l.summary.warrantyUntil, '');
      expect(l.summary.inWarranty, isFalse);
      expect(l.summary.revisitsLeft, 0);
    });

    test('null in every key of the line gives the same defaults', () {
      final l = _line({for (final key in _yearlyLine.keys) key: null});
      expect(l.orderItemId, 0);
      expect(l.visits, isEmpty);
      expect(l.hasPlan, isFalse);
      expect(l.summary.planVisits, 1);
      expect(l.summary.warrantyUntil, '');
      expect(l.title, '');
    });

    test('a summary, plan or visits of the wrong type is ignored', () {
      final l = _line({
        ..._yearlyLine,
        'summary': <dynamic>[],
        'visits': {'0': _visit1Done},
      });
      expect(l.summary.planVisits, 1);
      expect(l.visits, isEmpty);

      final s = BookingVisitsSummary.fromJson({'plan': 'yearly'});
      expect(s.planVisits, 1);
      expect(s.warrantyDays, 0);
    });

    test('a summary with no plan keeps its own values', () {
      final s = BookingVisitsSummary.fromJson({
        'work_finished': true,
        'warranty_until': '2027-02-08',
        'in_warranty': true,
        'revisits_left': 2,
      });
      expect(s.planVisits, 1);
      expect(s.warrantyDays, 0);
      expect(s.freeRevisits, 0);
      expect(s.workFinished, isTrue);
      expect(s.warrantyUntil, '2027-02-08');
      expect(s.inWarranty, isTrue);
      expect(s.revisitsLeft, 2);
    });

    test('null in every key of the summary and plan gives defaults', () {
      final s = BookingVisitsSummary.fromJson({
        'plan': {'visits': null, 'warranty_days': null, 'free_revisits': null},
        'work_finished': null,
        'warranty_until': null,
        'in_warranty': null,
        'revisits_left': null,
      });
      expect(s.planVisits, 1);
      expect(s.warrantyDays, 0);
      expect(s.freeRevisits, 0);
      expect(s.workFinished, isFalse);
      expect(s.warrantyUntil, '');
      expect(s.inWarranty, isFalse);
      expect(s.revisitsLeft, 0);
    });

    test('visits that are not objects are skipped', () {
      final l = _line({
        ..._yearlyLine,
        'visits': [null, 5, 'x', _visit2Pending],
      });
      expect(l.visits.map((v) => v.id), [22]);
    });

    test('an empty visit, or null in every key, gives safe defaults', () {
      for (final json in [
        const <String, dynamic>{},
        {for (final key in _visit1Done.keys) key: null},
      ]) {
        final v = BookingVisit.fromJson(json);
        expect(v.id, 0, reason: '$json');
        expect(v.visitNo, 0);
        expect(v.kind, '');
        expect(v.status, '');
        expect(v.dueDate, '');
        expect(v.bookingDate, '');
        expect(v.bookingSlotId, isNull);
        expect(v.bookingTimeLabel, '');
        expect(v.technicianName, '');
        expect(v.completedAt, '');
        expect(v.canSchedule, isFalse);
        expect(v.isRevisit, isFalse);
        expect(v.isDone, isFalse);
        expect(v.isSkipped, isFalse);
        expect(v.isScheduled, isFalse);
        expect(v.isOpen, isFalse);
      }
    });

    test('numbers sent as text and flags as 1 or "1" are read', () {
      final l = _line({
        ..._warrantyLine,
        'order_item_id': '502',
        'branch_id': '4',
        'summary': {
          'plan': {'visits': '1', 'warranty_days': '90', 'free_revisits': '2'},
          'work_finished': 1,
          'warranty_until': '2027-02-08',
          'in_warranty': '1',
          'revisits_left': '1',
        },
        'visits': [
          {..._scheduledRevisit, 'id': '31', 'booking_slot_id': '5'},
        ],
        'can_request_revisit': 1,
        'has_plan': '1',
      });
      expect(l.orderItemId, 502);
      expect(l.branchId, 4);
      expect(l.summary.warrantyDays, 90);
      expect(l.summary.freeRevisits, 2);
      expect(l.summary.workFinished, isTrue);
      expect(l.summary.inWarranty, isTrue);
      expect(l.summary.revisitsLeft, 1);
      expect(l.visits.single.id, 31);
      expect(l.visits.single.bookingSlotId, 5);
      expect(l.canRequestRevisit, isTrue);
      expect(l.hasPlan, isTrue);
    });
  });

  group('BookingVisitsLine title and package', () {
    test('the service is the title, the package below it', () {
      final l = _line(Map.of(_yearlyLine));
      expect(l.title, 'Cockroach Control');
      expect(l.package, '2 BHK - Yearly (3 visits)');
    });

    test('a deleted service makes the package the title', () {
      final l = _line({..._yearlyLine, 'service_name': ''});
      expect(l.title, '2 BHK - Yearly (3 visits)');
      expect(l.package, '');
    });

    test('a blank or missing service name counts as deleted', () {
      for (final name in ['  ', null]) {
        final l = _line({..._yearlyLine, 'service_name': name});
        expect(l.title, '2 BHK - Yearly (3 visits)', reason: '$name');
        expect(l.package, '', reason: '$name');
      }
    });

    test('a package named like its service is not shown twice', () {
      final l = _line({
        ..._yearlyLine,
        'service_name': 'Termite Control',
        'product_name': ' Termite Control ',
      });
      expect(l.title, 'Termite Control');
      expect(l.package, '');
    });

    test('names are trimmed', () {
      final l = _line({
        ..._yearlyLine,
        'service_name': ' Cockroach Control ',
        'product_name': ' 2 BHK ',
      });
      expect(l.title, 'Cockroach Control');
      expect(l.package, '2 BHK');
    });
  });

  group('BookingVisitsRepository.fetchForBooking', () {
    test('sends order_id and reads the lines of the live answer', () async {
      final api = _FakeApiClient(
        body: _answer([_yearlyLine, _warrantyLine, _plainLine]),
      );
      final lines = await BookingVisitsRepository(
        apiClient: api,
      ).fetchForBooking('345');
      expect(api.lastMethod, 'GET');
      expect(api.lastEndpoint, ApiEndpoints.bookingVisits);
      expect(api.lastQuery, {'order_id': '345'});
      expect(lines.map((l) => l.orderItemId), [501, 502, 503]);
      expect(lines[0].visits.length, 3);
      expect(lines[1].visits.single.isScheduled, isTrue);
      expect(lines[2].hasPlan, isFalse);
    });

    test('no lines, or no data, is an empty list', () async {
      for (final body in [
        _answer(const []),
        {'status': 1, 'data': <dynamic>[]},
        {
          'status': 1,
          'data': {'lines': null},
        },
        {'status': 1},
      ]) {
        final lines = await BookingVisitsRepository(
          apiClient: _FakeApiClient(body: body),
        ).fetchForBooking('345');
        expect(lines, isEmpty, reason: '$body');
      }
    });

    test('lines that are not objects are skipped', () async {
      final lines = await BookingVisitsRepository(
        apiClient: _FakeApiClient(body: _answer([null, 5, 'x', _warrantyLine])),
      ).fetchForBooking('345');
      expect(lines.map((l) => l.orderItemId), [502]);
    });

    test('an API error is passed on as it is', () async {
      final error = ApiException(message: 'order_not_found', statusCode: 404);
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(error: error),
        ).fetchForBooking('345'),
        throwsA(same(error)),
      );
    });

    test('an answer that is not an object becomes an ApiException', () async {
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(body: 'oops'),
        ).fetchForBooking('345'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('BookingVisitsRepository.schedule', () {
    test('posts id, date and window as text and returns the message', () async {
      final api = _FakeApiClient(
        body: {'status': 1, 'message': 'Visit scheduled'},
      );
      final message = await BookingVisitsRepository(
        apiClient: api,
      ).schedule(visitId: 22, date: '2026-12-24', slotId: 3);
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, ApiEndpoints.scheduleBookingVisit);
      expect(api.lastData, {
        'id': '22',
        'booking_date': '2026-12-24',
        'booking_slot_id': '3',
      });
      final data = api.lastData as Map;
      expect(data.values, everyElement(isA<String>()));
      expect(message, 'Visit scheduled');
    });

    test('an answer with no message returns empty text', () async {
      final message = await BookingVisitsRepository(
        apiClient: _FakeApiClient(body: {'status': 1}),
      ).schedule(visitId: 22, date: '2026-12-24', slotId: 3);
      expect(message, '');
    });

    test('a refusal is passed on as it is', () async {
      final error = ApiException(
        message: 'visit_is_today_call_us_to_change',
        statusCode: 200,
      );
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(error: error),
        ).schedule(visitId: 22, date: '2026-11-27', slotId: 3),
        throwsA(same(error)),
      );
    });

    test('an answer that is not an object becomes an ApiException', () async {
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(body: 'oops'),
        ).schedule(visitId: 22, date: '2026-12-24', slotId: 3),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('BookingVisitsRepository.requestRevisit', () {
    test('posts order_item_id and the trimmed note', () async {
      final api = _FakeApiClient(
        body: {'status': 1, 'message': 'Re-visit requested'},
      );
      final message = await BookingVisitsRepository(
        apiClient: api,
      ).requestRevisit(orderItemId: 502, notes: '  bugs are back  ');
      expect(api.lastMethod, 'POST');
      expect(api.lastEndpoint, ApiEndpoints.requestRevisit);
      expect(api.lastData, {'order_item_id': '502', 'notes': 'bugs are back'});
      expect(message, 'Re-visit requested');
    });

    test('no note, or a blank one, sends no notes key', () async {
      for (final notes in [null, '', '   ', '\n\t']) {
        final api = _FakeApiClient(body: {'status': 1, 'message': 'ok'});
        await BookingVisitsRepository(
          apiClient: api,
        ).requestRevisit(orderItemId: 502, notes: notes);
        expect(api.lastData, {'order_item_id': '502'}, reason: '"$notes"');
      }
    });

    test('a refusal is passed on as it is', () async {
      final error = ApiException(message: 'no_revisits_left', statusCode: 200);
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(error: error),
        ).requestRevisit(orderItemId: 502),
        throwsA(same(error)),
      );
    });
  });

  group('BookingVisitsCubit', () {
    test('starts empty', () async {
      final cubit = BookingVisitsCubit(
        orderId: '345',
        repository: _FakeRepository(() async => const []),
      );
      expect(cubit.state, isEmpty);
      await cubit.close();
    });

    test(
      'load asks for its booking and keeps only lines with a plan',
      () async {
        final repo = _FakeRepository(
          () async => [
            _line(Map.of(_yearlyLine)),
            _line(Map.of(_plainLine)),
            _line(Map.of(_warrantyLine)),
          ],
        );
        final cubit = BookingVisitsCubit(orderId: '345', repository: repo);
        await cubit.load();
        expect(repo.orderIds, ['345']);
        expect(cubit.state.map((l) => l.orderItemId), [501, 502]);
        await cubit.close();
      },
    );

    test('a booking with no plan lines shows nothing', () async {
      final cubit = BookingVisitsCubit(
        orderId: '345',
        repository: _FakeRepository(() async => [_line(Map.of(_plainLine))]),
      );
      await cubit.load();
      expect(cubit.state, isEmpty);
      await cubit.close();
    });

    test(
      'a failed first load leaves the list empty and does not throw',
      () async {
        final cubit = BookingVisitsCubit(
          orderId: '345',
          repository: _FakeRepository(
            () async =>
                throw ApiException(message: 'order_not_found', statusCode: 404),
          ),
        );
        await expectLater(cubit.load(), completes);
        expect(cubit.state, isEmpty);
        await cubit.close();
      },
    );

    test('a failed reload keeps the lines shown', () async {
      var fail = false;
      final cubit = BookingVisitsCubit(
        orderId: '345',
        repository: _FakeRepository(() async {
          if (fail) throw StateError('network down');
          return [_line(Map.of(_warrantyLine))];
        }),
      );
      await cubit.load();
      fail = true;
      await expectLater(cubit.load(), completes);
      expect(cubit.state.map((l) => l.orderItemId), [502]);
      await cubit.close();
    });

    test('load after close does not throw', () async {
      final cubit = BookingVisitsCubit(
        orderId: '345',
        repository: _FakeRepository(() async => [_line(Map.of(_yearlyLine))]),
      );
      await cubit.close();
      await expectLater(cubit.load(), completes);
      expect(cubit.state, isEmpty);
    });

    test('closing while a load is on its way does not throw', () async {
      final cubit = BookingVisitsCubit(
        orderId: '345',
        repository: _FakeRepository(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return [_line(Map.of(_yearlyLine))];
        }),
      );
      final loading = cubit.load();
      await cubit.close();
      await expectLater(loading, completes);
    });
  });
}
