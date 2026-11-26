// PestRaksh: fetches the booking dates and arrival windows (`available_slots`).
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/features/checkout/models/booking_slots_model.dart';

class BookingSlotsRepository {
  BookingSlotsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The next [days] dates from today (the server's today, India time) for the
  /// schedule of [branchId]; the backend falls back to the shared schedule
  /// (branch 0) when the branch has none of its own.
  Future<List<BookingSlotDate>> fetch({
    required int branchId,
    int days = 30,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.availableSlots,
        queryParameters: {
          ApiParameters.branchId: branchId.toString(),
          ApiParameters.days: days.toString(),
        },
      );
      final data = (response as Map<String, dynamic>)['data'];
      final dates = data is Map<String, dynamic> ? data['dates'] : null;
      if (dates is! List) return const [];
      return [
        for (final d in dates)
          if (d is Map<String, dynamic>) BookingSlotDate.fromJson(d),
      ];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
