import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/category/models/category_layout_model.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:dio/dio.dart';

class CategoryRepository {
  final ApiClient _apiClient;

  CategoryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PaginatedResponse<Category>> getCategories({
    required int offset,
    required int limit,
    String? categoryId,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
        ApiParameters.categoryId: ?categoryId,
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
      };
      final response = await _apiClient.get(
        ApiEndpoints.categories,
        queryParameters: params,
      );
      return PaginatedResponse.fromJson(
        response as Map<String, dynamic>,
        Category.fromJson,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Categories screen from the Category Builder. The server picks the
  /// layout for the location's zone and [channel]; the bearer token (sent by
  /// the interceptor when logged in) gives the same per-user product data
  /// as home.
  Future<CategoryLayoutModel> getCategoryLayout({
    required String channel,
    int offset = 0,
    int limit = AppConstants.homeSectionsPageLimit,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.latitude: SettingsHiveBox.instance.userLatitude,
        ApiParameters.longitude: SettingsHiveBox.instance.userLongitude,
        ApiParameters.device: AppSizes.isTabletDevice
            ? ApiParameters.tablet
            : ApiParameters.app,
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      };
      final response = await _apiClient.get(
        ApiEndpoints.categoryLayout,
        queryParameters: params,
        // Pinned per request, as on home, so every page of one load comes
        // from the same channel even if the session channel flips mid-flight.
        options: Options(headers: {ApiParameters.channel: channel}),
      );
      return CategoryLayoutModel.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
