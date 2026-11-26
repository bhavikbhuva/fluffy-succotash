import 'package:customer/core/api/api_parameters.dart';

/// Server-side scope of a home product row (product_slider block or one tab
/// of product_tabs). Passed through unchanged to View More so its list — and
/// the filter sheet's counts — match the row that was tapped.
class ProductListScope {
  final String? dataSource;

  /// Comma-separated, already includes child categories — never expand it.
  final String? categoryIds;
  final String? brandIds;

  /// "exclude" flips [categoryIds]/[brandIds] to "everything except these".
  /// Null when the server didn't send it — never default it.
  final String? filterMode;
  final String? manualProductIds;

  // "Product list with filters" (automatic data sources only): kept as the
  // server's strings and sent back exactly as received.
  final String? attributeValueIds;
  final String? minPrice;
  final String? maxPrice;
  final String? minDiscountPercent;
  final String? maxDiscountPercent;

  const ProductListScope({
    this.dataSource,
    this.categoryIds,
    this.brandIds,
    this.filterMode,
    this.manualProductIds,
    this.attributeValueIds,
    this.minPrice,
    this.maxPrice,
    this.minDiscountPercent,
    this.maxDiscountPercent,
  });

  static const _automaticSources = {
    'top_selling',
    'trending',
    'new_arrivals',
    'best_rated',
    'discounted',
    'most_favorited',
    'recently_visited',
    'buy_again',
  };

  /// View More query map for an automatic-source row without filter_mode:
  /// the row's brands/attributes/price/discount are ordinary filters, so they
  /// go through the banner redirect_params path — pre-selected in the sheet,
  /// changeable there, and sent unchanged to both products and filters.
  /// data_source stays the row's own (never "category"). Null for manual /
  /// category / brand rows and legacy exclude rows, which keep the scope path.
  Map<String, String>? get filterParams {
    final source = dataSource;
    if (source == null || !_automaticSources.contains(source)) return null;
    if (filterMode != null) return null;
    return {
      ApiParameters.dataSource: source,
      ApiParameters.categoryId: ?categoryIds,
      ApiParameters.brandIds: ?brandIds,
      ApiParameters.attributeValues: ?attributeValueIds,
      ApiParameters.minPrice: ?minPrice,
      ApiParameters.maxPrice: ?maxPrice,
      ApiParameters.minDiscountPercent: ?minDiscountPercent,
      ApiParameters.maxDiscountPercent: ?maxDiscountPercent,
    };
  }
}

typedef ViewMoreTapCallback =
    void Function(String title, ProductListScope scope);
