class CategoryRedirectArgs {
  final String categoryId;

  /// Mirrors CategoryScreen's own tap rule: true opens the subcategory
  /// sidebar+grid screen, false skips straight to that category's products.
  final bool hasChild;

  /// Optional display title known up front (e.g. from a push notification's
  /// `type_name`), shown immediately instead of waiting on the category
  /// fetch to resolve one.
  final String? categoryName;

  /// Home layout redirect_params' data_source, sent on every product /
  /// filter call of the opened screen. Null when the server didn't send it —
  /// never default it.
  final String? dataSource;

  const CategoryRedirectArgs({
    required this.categoryId,
    required this.hasChild,
    this.categoryName,
    this.dataSource,
  });
}
