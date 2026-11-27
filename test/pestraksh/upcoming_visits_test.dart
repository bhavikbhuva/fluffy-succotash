// PestRaksh: follow-up visits on My Bookings → Upcoming, the data side: the
// visit model, the repository's reading of `booking_visits/upcoming` and the
// quiet cubit.
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/orders/cubit/upcoming_visits_cubit.dart';
import 'package:customer/features/orders/models/upcoming_visit_model.dart';
import 'package:customer/features/orders/repositories/booking_visits_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visit 2 of a yearly plan, no time chosen yet, as `upcoming` builds it.
const _pendingVisit = {
  'id': 12,
  'order_id': 345,
  'order_number': 'PR-000345',
  'visit_no': 2,
  'visits_total': 3,
  'kind': 'visit',
  'status': 'pending',
  'due_date': '2027-02-25',
  'booking_date': null,
  'booking_time_label': null,
  'service_name': 'Cockroach Control',
  'product_name': '2 BHK - Yearly (3 visits)',
  'overdue': false,
};

/// A warranty re-visit with its date and window chosen.
const _scheduledRevisit = {
  'id': 13,
  'order_id': 346,
  'order_number': 'PR-000346',
  'visit_no': 2,
  'visits_total': 1,
  'kind': 'revisit',
  'status': 'scheduled',
  'due_date': '2026-11-30',
  'booking_date': '2026-12-01',
  'booking_time_label': '09:00 AM - 11:00 AM',
  'service_name': 'Bed Bug Control',
  'product_name': '1 BHK',
  'overdue': false,
};

/// Never reached: the fake repositories below don't call the API. It keeps the
/// tests off the real ApiClient singleton.
class _UnusedApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the API is not used in this test');
}

/// Answers `get` with a fixed body, or throws [error].
class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.body, this.error});

  final Object? body;
  final Object? error;
  String? lastEndpoint;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? options,
    Object? cancelToken,
  }) async {
    lastEndpoint = endpoint;
    if (error != null) throw error!;
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('only get is faked');
}

class _FakeRepository extends BookingVisitsRepository {
  _FakeRepository(this._answer) : super(apiClient: _UnusedApiClient());

  final Future<List<UpcomingVisit>> Function() _answer;
  int calls = 0;

  @override
  Future<List<UpcomingVisit>> fetchUpcoming() {
    calls++;
    return _answer();
  }
}

void main() {
  group('UpcomingVisit.fromJson', () {
    test('a pending visit 2 of 3 has its due date and no time yet', () {
      final v = UpcomingVisit.fromJson(Map.of(_pendingVisit));
      expect(v.id, 12);
      expect(v.orderId, 345);
      expect(v.orderNumber, 'PR-000345');
      expect(v.visitNo, 2);
      expect(v.visitsTotal, 3);
      expect(v.visitsShownTotal, 3);
      expect(v.dueDate, '2027-02-25');
      expect(v.bookingDate, '');
      expect(v.bookingTimeLabel, '');
      expect(v.isScheduled, isFalse);
      expect(v.isRevisit, isFalse);
      expect(v.overdue, isFalse);
      expect(v.title, 'Cockroach Control');
      expect(v.package, '2 BHK - Yearly (3 visits)');
    });

    test('a scheduled re-visit has its date and window', () {
      final v = UpcomingVisit.fromJson(Map.of(_scheduledRevisit));
      expect(v.isScheduled, isTrue);
      expect(v.isRevisit, isTrue);
      expect(v.bookingDate, '2026-12-01');
      expect(v.bookingTimeLabel, '09:00 AM - 11:00 AM');
      expect(v.title, 'Bed Bug Control');
      expect(v.package, '1 BHK');
    });

    test('an overdue pending visit reads overdue', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'due_date': '2026-11-20',
        'overdue': true,
      });
      expect(v.overdue, isTrue);
      expect(v.isScheduled, isFalse);
    });

    test('a deleted service makes the package the title', () {
      final v = UpcomingVisit.fromJson({..._pendingVisit, 'service_name': ''});
      expect(v.title, '2 BHK - Yearly (3 visits)');
      expect(v.package, '');
    });

    test('a blank service name counts as deleted', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'service_name': '  ',
      });
      expect(v.title, '2 BHK - Yearly (3 visits)');
      expect(v.package, '');
    });

    test('a package named like its service is not shown twice', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'service_name': 'Termite Control',
        'product_name': ' Termite Control ',
      });
      expect(v.title, 'Termite Control');
      expect(v.package, '');
    });

    test('the total shown is never below the visit number', () {
      final v = UpcomingVisit.fromJson({
        ..._scheduledRevisit,
        'visit_no': 3,
        'visits_total': 1,
      });
      expect(v.visitsTotal, 1);
      expect(v.visitsShownTotal, 3);
    });

    test('the total shown is the plan total when it is larger', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'visit_no': 1,
        'visits_total': 4,
      });
      expect(v.visitsShownTotal, 4);
    });

    test('scheduled with no booking date is not scheduled', () {
      for (final date in [null, '']) {
        final v = UpcomingVisit.fromJson({
          ..._scheduledRevisit,
          'booking_date': date,
        });
        expect(v.isScheduled, isFalse, reason: 'booking_date $date');
      }
    });

    test('a pending visit with a booking date is not scheduled', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'booking_date': '2027-02-25',
      });
      expect(v.isScheduled, isFalse);
    });

    test('an empty object gives safe defaults', () {
      final v = UpcomingVisit.fromJson(const {});
      expect(v.id, 0);
      expect(v.orderId, 0);
      expect(v.orderNumber, '');
      expect(v.visitNo, 0);
      expect(v.visitsTotal, 1);
      expect(v.visitsShownTotal, 1);
      expect(v.kind, '');
      expect(v.status, '');
      expect(v.dueDate, '');
      expect(v.bookingDate, '');
      expect(v.bookingTimeLabel, '');
      expect(v.serviceName, '');
      expect(v.productName, '');
      expect(v.overdue, isFalse);
      expect(v.isScheduled, isFalse);
      expect(v.isRevisit, isFalse);
      expect(v.title, '');
      expect(v.package, '');
    });

    test('null in every key gives the same safe defaults', () {
      final v = UpcomingVisit.fromJson({
        for (final key in _pendingVisit.keys) key: null,
      });
      expect(v.id, 0);
      expect(v.visitNo, 0);
      expect(v.visitsTotal, 1);
      expect(v.visitsShownTotal, 1);
      expect(v.status, '');
      expect(v.title, '');
      expect(v.package, '');
      expect(v.overdue, isFalse);
    });

    test('numbers sent as text and overdue as 1 are read', () {
      final v = UpcomingVisit.fromJson({
        ..._pendingVisit,
        'id': '12',
        'visit_no': '2',
        'visits_total': '3',
        'overdue': 1,
      });
      expect(v.id, 12);
      expect(v.visitNo, 2);
      expect(v.visitsTotal, 3);
      expect(v.overdue, isTrue);
    });
  });

  group('BookingVisitsRepository.fetchUpcoming', () {
    test('reads the visits of the live answer', () async {
      final api = _FakeApiClient(
        body: {
          'status': 1,
          'data': {
            'visits': [_pendingVisit, _scheduledRevisit],
            'today': '2026-11-27',
          },
        },
      );
      final visits = await BookingVisitsRepository(
        apiClient: api,
      ).fetchUpcoming();
      expect(api.lastEndpoint, ApiEndpoints.upcomingBookingVisits);
      expect(visits.map((v) => v.id), [12, 13]);
      expect(visits.last.isScheduled, isTrue);
    });

    test('no visits, or no data, is an empty list', () async {
      for (final body in [
        {
          'status': 1,
          'data': {'visits': <dynamic>[], 'today': '2026-11-27'},
        },
        {'status': 1, 'data': <dynamic>[]},
        {'status': 1},
      ]) {
        final visits = await BookingVisitsRepository(
          apiClient: _FakeApiClient(body: body),
        ).fetchUpcoming();
        expect(visits, isEmpty, reason: '$body');
      }
    });

    test('entries that are not objects are skipped', () async {
      final visits = await BookingVisitsRepository(
        apiClient: _FakeApiClient(
          body: {
            'status': 1,
            'data': {
              'visits': [null, 5, 'x', _pendingVisit],
            },
          },
        ),
      ).fetchUpcoming();
      expect(visits.map((v) => v.id), [12]);
    });

    test('an API error is passed on as it is', () async {
      final error = ApiException(message: 'Not found', statusCode: 404);
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(error: error),
        ).fetchUpcoming(),
        throwsA(same(error)),
      );
    });

    test('an answer that is not an object becomes an ApiException', () async {
      await expectLater(
        BookingVisitsRepository(
          apiClient: _FakeApiClient(body: 'oops'),
        ).fetchUpcoming(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('UpcomingVisitsCubit', () {
    test('starts empty', () async {
      final cubit = UpcomingVisitsCubit(
        repository: _FakeRepository(() async => const []),
      );
      expect(cubit.state, isEmpty);
      await cubit.close();
    });

    test('load emits the visits', () async {
      final repo = _FakeRepository(
        () async => [
          UpcomingVisit.fromJson(Map.of(_pendingVisit)),
          UpcomingVisit.fromJson(Map.of(_scheduledRevisit)),
        ],
      );
      final cubit = UpcomingVisitsCubit(repository: repo);
      await cubit.load();
      expect(repo.calls, 1);
      expect(cubit.state.map((v) => v.id), [12, 13]);
      await cubit.close();
    });

    test(
      'a failed first load leaves the list empty and does not throw',
      () async {
        final cubit = UpcomingVisitsCubit(
          repository: _FakeRepository(
            () async =>
                throw ApiException(message: 'Not found', statusCode: 404),
          ),
        );
        await expectLater(cubit.load(), completes);
        expect(cubit.state, isEmpty);
        await cubit.close();
      },
    );

    test('a failed reload keeps the visits shown', () async {
      var fail = false;
      final cubit = UpcomingVisitsCubit(
        repository: _FakeRepository(() async {
          if (fail) throw StateError('network down');
          return [UpcomingVisit.fromJson(Map.of(_pendingVisit))];
        }),
      );
      await cubit.load();
      fail = true;
      await expectLater(cubit.load(), completes);
      expect(cubit.state.map((v) => v.id), [12]);
      await cubit.close();
    });

    test('a reload with no visits left empties the list', () async {
      var visits = [UpcomingVisit.fromJson(Map.of(_pendingVisit))];
      final cubit = UpcomingVisitsCubit(
        repository: _FakeRepository(() async => visits),
      );
      await cubit.load();
      visits = [];
      await cubit.load();
      expect(cubit.state, isEmpty);
      await cubit.close();
    });

    test('load after close does not throw', () async {
      final cubit = UpcomingVisitsCubit(
        repository: _FakeRepository(
          () async => [UpcomingVisit.fromJson(Map.of(_pendingVisit))],
        ),
      );
      await cubit.close();
      await expectLater(cubit.load(), completes);
      expect(cubit.state, isEmpty);
    });

    test('closing while a load is on its way does not throw', () async {
      final cubit = UpcomingVisitsCubit(
        repository: _FakeRepository(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return [UpcomingVisit.fromJson(Map.of(_pendingVisit))];
        }),
      );
      final loading = cubit.load();
      await cubit.close();
      await expectLater(loading, completes);
    });
  });
}
