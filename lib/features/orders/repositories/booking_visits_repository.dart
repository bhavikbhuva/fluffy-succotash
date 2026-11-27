// PestRaksh: the customer's follow-up visits still to come.
import 'package:customer/core/api/api_client.dart';
import 'package:customer/utils/json_parsers.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/orders/models/booking_visits_model.dart';
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

  /// The services of booking [orderId] with their visits and warranty.
  Future<List<BookingVisitsLine>> fetchForBooking(String orderId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.bookingVisits,
        queryParameters: {'order_id': orderId},
      );
      final data = (response as Map<String, dynamic>)['data'];
      final lines = data is Map<String, dynamic> ? data['lines'] : null;
      if (lines is! List) return const [];
      return [
        for (final l in lines)
          if (l is Map<String, dynamic>) BookingVisitsLine.fromJson(l),
      ];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Books visit [visitId] for [date] ("YYYY-MM-DD") in window [slotId].
  /// Returns the server's message ("Visit scheduled"); throws [ApiException]
  /// with the server's reason when refused (for example the window is full).
  Future<String> schedule({
    required int visitId,
    required String date,
    required int slotId,
  }) => _post(ApiEndpoints.scheduleBookingVisit, {
    'id': visitId.toString(),
    'booking_date': date,
    'booking_slot_id': slotId.toString(),
  });

  /// Asks for a free re-visit of booked service [orderItemId], with an
  /// optional note of what the customer noticed.
  Future<String> requestRevisit({required int orderItemId, String? notes}) =>
      _post(ApiEndpoints.requestRevisit, {
        'order_item_id': orderItemId.toString(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });

  Future<String> _post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(endpoint, data: data);
      return parseString((response as Map<String, dynamic>)['message']) ?? '';
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
