// PestRaksh: follow-up visits shown at the top of My Bookings → Upcoming.
// Quiet on failure, as on the website: the tab then just has no visits.
import 'package:customer/features/orders/models/upcoming_visit_model.dart';
import 'package:customer/features/orders/repositories/booking_visits_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpcomingVisitsCubit extends Cubit<List<UpcomingVisit>> {
  UpcomingVisitsCubit({BookingVisitsRepository? repository})
    : _repository = repository ?? BookingVisitsRepository(),
      super(const []);

  final BookingVisitsRepository _repository;

  Future<void> load() async {
    try {
      final visits = await _repository.fetchUpcoming();
      if (!isClosed) emit(visits);
    } catch (_) {
      // Keep what is shown; an older backend has no such endpoint.
    }
  }
}
