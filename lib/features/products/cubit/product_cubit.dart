import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/models/product_sort_type.dart';
import '../repositories/product_repository.dart';

// ── Filter ──────────────────────────────────────────────────────────────────
class ProductFilter {
  final String categoryId;
  final String? dataSource;
  final String? manualProductIds;
  // Fixed scope (e.g. "products of this brand") — always sent alongside the
  // filter sheet's own brandIds selection, and preserved across sort/filter
  // changes and clearFilters(), unlike brandIds which the user controls.
  final String? brandId;
  // Home row scope (View More), preserved like brandId: the row's brand_ids
  // and filter_mode ("exclude" = everything except the scoped ids).
  final String? scopeBrandIds;
  final String? filterMode;
  final ProductSortType sort;
  final double? minPrice;
  final double? maxPrice;
  final Set<String> brandIds;
  final Set<String> attributeValueIds;
  // Banner-only (redirect_type "products"): no control in the filter sheet,
  // so they ride along with every sheet change and drop on clearFilters().
  // Kept as the server's strings (0-100) — sent back as they came.
  final String? minDiscountPercent;
  final String? maxDiscountPercent;
  // Banner redirect_params keys with no field above, sent back exactly as
  // received on every request — the API asks that the map never be cut
  // down to the keys the app knows. Scope, so kept on clearFilters().
  final Map<String, String> extraParams;

  const ProductFilter({
    required this.categoryId,
    this.dataSource,
    this.manualProductIds,
    this.brandId,
    this.scopeBrandIds,
    this.filterMode,
    this.sort = ProductSortType.defaultSort,
    this.minPrice,
    this.maxPrice,
    this.brandIds = const {},
    this.attributeValueIds = const {},
    this.minDiscountPercent,
    this.maxDiscountPercent,
    this.extraParams = const {},
  });

  // Keys fromRedirectParams maps onto fields; everything else rides along
  // in extraParams.
  static const _mappedRedirectKeys = {
    ApiParameters.categoryId,
    ApiParameters.dataSource,
    ApiParameters.manualProductIds,
    ApiParameters.filterMode,
    ApiParameters.sort,
    ApiParameters.minPrice,
    ApiParameters.maxPrice,
    ApiParameters.brandIds,
    ApiParameters.attributeValues,
    ApiParameters.minDiscountPercent,
    ApiParameters.maxDiscountPercent,
  };

  /// Initial state from a home banner's redirect_params. category_id (may be
  /// a comma list — sent as-is, never split/reordered), data_source and
  /// manual_product_ids become the screen's scope (kept on clear) —
  /// data_source "category" makes the server match the whole subtree,
  /// without it a parent category lists nothing. With filter_mode set,
  /// brand_ids is scope too (same as a home row's View More); without it,
  /// brand_ids is an ordinary pick. The rest are ordinary, clearable filters
  /// pre-selected in the sheet, and unknown keys go to [extraParams]. Absent
  /// keys stay null/empty — never filled with 0 or "". An unknown sort falls
  /// back to the default.
  factory ProductFilter.fromRedirectParams(Map<String, String> params) {
    Set<String> csv(String? raw) => {
      for (final id in (raw ?? '').split(','))
        if (id.trim().isNotEmpty) id.trim(),
    };
    String? nonEmpty(String key) {
      final v = params[key];
      return (v ?? '').isEmpty ? null : v;
    }

    final sort = params[ApiParameters.sort];
    final filterMode = nonEmpty(ApiParameters.filterMode);
    final brandIds = nonEmpty(ApiParameters.brandIds);
    return ProductFilter(
      categoryId: params[ApiParameters.categoryId] ?? '',
      dataSource: nonEmpty(ApiParameters.dataSource),
      manualProductIds: nonEmpty(ApiParameters.manualProductIds),
      scopeBrandIds: filterMode != null ? brandIds : null,
      filterMode: filterMode,
      sort: ProductSortType.values.firstWhere(
        (t) => sort != null && sort.isNotEmpty && t.apiValue == sort,
        orElse: () => ProductSortType.defaultSort,
      ),
      minPrice: double.tryParse(params[ApiParameters.minPrice] ?? ''),
      maxPrice: double.tryParse(params[ApiParameters.maxPrice] ?? ''),
      brandIds: filterMode != null ? const {} : csv(brandIds),
      attributeValueIds: csv(params[ApiParameters.attributeValues]),
      minDiscountPercent: params[ApiParameters.minDiscountPercent],
      maxDiscountPercent: params[ApiParameters.maxDiscountPercent],
      extraParams: {
        for (final e in params.entries)
          if (!_mappedRedirectKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  bool get hasActiveFilters =>
      brandIds.isNotEmpty ||
      attributeValueIds.isNotEmpty ||
      minPrice != null ||
      maxPrice != null ||
      minDiscountPercent != null ||
      maxDiscountPercent != null;

  ProductFilter copyWithSort(ProductSortType sort) => ProductFilter(
    categoryId: categoryId,
    dataSource: dataSource,
    manualProductIds: manualProductIds,
    brandId: brandId,
    scopeBrandIds: scopeBrandIds,
    filterMode: filterMode,
    sort: sort,
    minPrice: minPrice,
    maxPrice: maxPrice,
    brandIds: brandIds,
    attributeValueIds: attributeValueIds,
    minDiscountPercent: minDiscountPercent,
    maxDiscountPercent: maxDiscountPercent,
    extraParams: extraParams,
  );

  ProductFilter copyWithFilters({
    double? minPrice,
    double? maxPrice,
    Set<String>? brandIds,
    Set<String>? attributeValueIds,
  }) => ProductFilter(
    categoryId: categoryId,
    dataSource: dataSource,
    manualProductIds: manualProductIds,
    brandId: brandId,
    scopeBrandIds: scopeBrandIds,
    filterMode: filterMode,
    sort: sort,
    minPrice: minPrice,
    maxPrice: maxPrice,
    brandIds: brandIds ?? const {},
    attributeValueIds: attributeValueIds ?? const {},
    minDiscountPercent: minDiscountPercent,
    maxDiscountPercent: maxDiscountPercent,
    extraParams: extraParams,
  );

  ProductFilter clearFilters() => ProductFilter(
    categoryId: categoryId,
    dataSource: dataSource,
    manualProductIds: manualProductIds,
    brandId: brandId,
    scopeBrandIds: scopeBrandIds,
    filterMode: filterMode,
    extraParams: extraParams,
  );
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class ProductCubit
    extends FilteredPaginationCubit<ProductDataModel, ProductFilter> {
  final ProductRepository _repository;

  // Response-derived filter metadata (brand list / price bounds) — not part
  // of the current selection, so it lives outside PaginationLoaded<T>.
  List<ProductFilterBrand> _brands = [];
  double _totalMinPrice = 0;
  double _totalMaxPrice = 0;

  List<ProductFilterBrand> get brands => _brands;
  double get totalMinPrice => _totalMinPrice;
  double get totalMaxPrice => _totalMaxPrice;

  // Grid shows more tiles per screen than list rows, so it fetches a larger
  // page. Kept on the cubit (not ProductFilter) since toggling it re-fetches
  // via the same filters rather than counting as a filter change.
  bool _isGrid = true;
  int get _limit => _isGrid ? AppConfig.gridPageLimit : AppConfig.pageLimit;

  ProductCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(const ProductFilter(categoryId: ''));

  @override
  bool computeHasMore(
    PaginatedResponse<ProductDataModel> response,
    List<ProductDataModel> allData,
  ) => response.data.length >= _limit;

  @override
  PaginationFetcher<ProductDataModel> buildFetcher(
    ProductFilter f,
  ) => (offset) async {
    // The sheet's brand picks already come from the row-scoped filters
    // list, so they replace the row's brand_ids rather than union with
    // it — a union would widen the list, and under filter_mode=exclude
    // would hide the very brands the user picked.
    final scopeBrandIds = f.scopeBrandIds;
    final picksReplaceScope = scopeBrandIds != null && f.brandIds.isNotEmpty;
    final result = await _repository.getProducts(
      offset: offset,
      limit: _limit,
      categoryId: f.categoryId,
      dataSource: f.dataSource,
      manualProductIds: f.manualProductIds,
      sort: f.sort.apiValue,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      brandIds: {
        if (f.brandId != null) f.brandId!,
        if (scopeBrandIds != null && !picksReplaceScope)
          ...scopeBrandIds.split(','),
        ...f.brandIds,
      }.toList(),
      attributeValueIds: f.attributeValueIds.toList(),
      minDiscountPercent: f.minDiscountPercent,
      maxDiscountPercent: f.maxDiscountPercent,
      filterMode: picksReplaceScope ? null : f.filterMode,
      extraParams: f.extraParams,
    );
    _brands = result.brands ?? [];
    _totalMinPrice = result.totalMinPrice ?? 0;
    _totalMaxPrice = result.totalMaxPrice ?? 0;
    return PaginatedResponse(data: result.data ?? [], total: result.total ?? 0);
  };

  Future<void> loadProducts({
    String categoryId = '',
    String? dataSource,
    String? manualProductIds,
    String? brandId,
    String? scopeBrandIds,
    String? filterMode,
    Map<String, String>? redirectParams,
    bool isGrid = true,
  }) {
    _isGrid = isGrid;
    return applyFilters(
      redirectParams != null
          ? ProductFilter.fromRedirectParams(redirectParams)
          : ProductFilter(
              categoryId: categoryId,
              dataSource: dataSource,
              manualProductIds: manualProductIds,
              brandId: brandId,
              scopeBrandIds: scopeBrandIds,
              filterMode: filterMode,
            ),
    );
  }

  Future<void> loadMore() => fetchMore();

  // Re-fetches from the top with the other page size. Loses the current
  // scroll position/accumulated pages by design — the two views paginate
  // independently.
  Future<void> setGridView(bool isGrid) {
    if (_isGrid == isGrid) return Future.value();
    _isGrid = isGrid;
    return applyFilters(currentFilters);
  }

  Future<void> applySort(ProductSortType sort) =>
      applyFilters(currentFilters.copyWithSort(sort));

  Future<void> applyProductFilters({
    double? minPrice,
    double? maxPrice,
    Set<String>? brandIds,
    Set<String>? attributeValueIds,
  }) => applyFilters(
    currentFilters.copyWithFilters(
      minPrice: minPrice,
      maxPrice: maxPrice,
      brandIds: brandIds,
      attributeValueIds: attributeValueIds,
    ),
  );

  Future<void> clearFilters() => applyFilters(currentFilters.clearFilters());
}
