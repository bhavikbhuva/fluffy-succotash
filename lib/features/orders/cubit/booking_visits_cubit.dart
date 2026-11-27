// PestRaksh: the "Visits & warranty" card of one booking (APP_PLAN Phase 4).
// Quiet on failure, as on the website: the card is then just not shown.
import 'package:customer/features/orders/models/booking_visits_model.dart';
import 'package:customer/features/orders/repositories/booking_visits_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BookingVisitsCubit extends Cubit<List<BookingVisitsLine>> {
  BookingVisitsCubit({
    required this.orderId,
    BookingVisitsRepository? repository,
  }) : repository = repository ?? BookingVisitsRepository(),
       super(const []);

  final String orderId;
  final BookingVisitsRepository repository;

  /// Only the services that have something to show (several visits, a
  /// warranty, or visits on record).
  Future<void> load() async {
    try {
      final lines = await repository.fetchForBooking(orderId);
      if (isClosed) return;
      emit([
        for (final l in lines)
          if (l.hasPlan) l,
      ]);
    } catch (_) {
      // Keep what is shown.
    }
  }
}
