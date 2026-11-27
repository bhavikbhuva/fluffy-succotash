// PestRaksh: the customer's follow-up visits still to come.
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/orders/models/upcoming_visit_model.dart';

class BookingVisitsRepository {
  BookingVisitsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<UpcomingVisit>> fetchUpcoming() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.upcomingBookingVisits);
      final data = (response as Map<String, dynamic>)['data'];
      final visits = data is Map<String, dynamic> ? data['visits'] : null;
      if (visits is! List) return const [];
      return [
        for (final v in visits)
          if (v is Map<String, dynamic>) UpcomingVisit.fromJson(v),
      ];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
