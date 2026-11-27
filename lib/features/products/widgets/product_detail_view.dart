import 'package:flutter/rendering.dart';
import 'package:customer/features/products/widgets/addon_section.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_network_video.dart';
import 'package:customer/utils/media_type.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/star_rating_row.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/features/products/cubit/product_detail_cubit.dart';
import 'package:customer/features/products/cubit/ratings_list_cubit.dart';
import 'package:customer/features/products/models/product_rating_model.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/features/products/models/package_plans_model.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/products/widgets/delivery_time_icon.dart';
import 'package:customer/features/products/widgets/product_detail_app_bar_widgets.dart';
import 'package:customer/features/products/widgets/product_detail_info_section.dart';
import 'package:customer/features/products/widgets/product_detail_rating_section.dart';
import 'package:customer/features/products/widgets/product_detail_upsell_section.dart';
import 'package:customer/features/products/widgets/product_pincode_check_section.dart';
import 'package:customer/features/products/widgets/recently_visited_section.dart';
import 'package:customer/features/products/widgets/similar_products_section.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Fixed cache dims for the detail hero image, independent of the
/// SliverAppBar's live collapse/expand constraints (which change every scroll
/// frame and would otherwise trigger a decode-cache miss + placeholder
/// flash). Shared with the loading view so its decoded image is the same
/// cache entry the gallery picks up once the product loads.
(int, int) productHeroMemCacheSize(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (
    (context.screenWidth * dpr).round(),
    (context.screenHeight * 0.38 * dpr).round(),
  );
}

class ProductDetailView extends StatefulWidget {
  final ProductDetailDataModel product;
  final int productId;
  final String heroSuffix;

  /// The tapped card's image, already decoded by the loading view — used as
  /// the first gallery page's placeholder so a different variant image URL
  /// doesn't flash the logo placeholder in between.
  final String? initialImageUrl;

  /// Suffix used only for this page's own Similar/Recently-Visited section
  /// cards — kept separate from [heroSuffix] so scoping it per-page (to
  /// dodge duplicate-tag crashes across concurrently-mounted pager pages)
  /// never breaks the main image hero's match against the tapped card.
  final String subSectionHeroSuffix;
  final int selectedVariantIndex;
  final Map<int, int> selectedAxisValues;
  final PageController imageController;
  final ScrollController scrollController;
  final int imagePage;
  final bool isCollapsed;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onImagePageChanged;

  /// Attached to the Upsell section so the bottom bar's "first add to
  /// cart" handler can scroll straight to it via [Scrollable.ensureVisible].
  final GlobalKey? upsellSectionKey;

  /// Fallback scroll targets when the Upsell section is empty/absent.
  final GlobalKey? similarSectionKey;
  final GlobalKey? recentlyVisitedSectionKey;

  /// Add-on module: answers for a `has_addons` product, listed right under
  /// the variants (shared with the bottom bar's ADD).
  final AddonController? addonController;

  const ProductDetailView({
    super.key,
    required this.product,
    required this.productId,
    this.heroSuffix = '',
    this.initialImageUrl,
    this.subSectionHeroSuffix = '',
    required this.selectedVariantIndex,
    required this.selectedAxisValues,
    required this.imageController,
    required this.scrollController,
    required this.imagePage,
    required this.isCollapsed,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onImagePageChanged,
    this.upsellSectionKey,
    this.similarSectionKey,
    this.recentlyVisitedSectionKey,
    this.addonController,
  });

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  bool _showKeyFeatures = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  /// Add-on product with a real choice: variants render as the variant
  /// sheet's radio card instead of attribute chips.
  bool get _showAddonVariantCard =>
      widget.addonController != null &&
      widget.product.requiresAddonSheet &&
      (widget.product.variants ?? []).length > 1;

  /// Attribute name(s) the chip UI showed above its row, e.g. "Size".
  String get _addonVariantTitle {
    final names = (widget.product.variantAxes ?? [])
        .map((axis) => axis.attributeName ?? '')
        .where((name) => name.isNotEmpty)
        .join(' / ');
    return names.isNotEmpty
        ? names
        : context.translate(LanguageLabelKeys.selectVariant);
  }

  /// Same row as the add-on variant sheet: label, price, radio.
  Widget _addonVariantRow(int i) {
    final v = widget.product.variants![i];
    final selected = i == widget.selectedVariantIndex;
    final disabled = v.inStock == false;
    final raw = v.price ?? 0;
    final disc = v.discountedPrice ?? 0;
    final price = disc > 0 && disc < raw ? disc : raw;
    final currency = widget.product.currency ?? '';
    final decimals = widget.product.decimalPoint ?? 2;
    final label = (v.attributes ?? [])
        .map((a) => a.attributeValue ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    final fg = disabled
        ? context.cs.onSurface.withValues(alpha: 0.38)
        : context.cs.onSurface;
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: disabled || selected
          ? null
          : () {
              // Every axis set to this variant's values → cubit lands on it.
              final cubit = context.read<ProductDetailCubit>();
              for (final a in v.attributes ?? <Attributes>[]) {
                if (a.attributeId == null || a.attributeValueId == null) {
                  continue;
                }
                cubit.selectAxisValue(a.attributeId!, a.attributeValueId!);
              }
            },
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                label.isNotEmpty ? label : v.name ?? '',
                style: context.tt.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AppSpacing.w8,
            if (price < raw) ...[
              AppText(
                '$currency${raw.formatPrice(decimals)}',
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.w4,
            ],
            AppText(
              '$currency${price.formatPrice(decimals)}',
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            AppSpacing.w12,
            AddonSelectIndicator(
              radio: true,
              selected: selected,
              enabled: !disabled,
            ),
          ],
        ),
      ),
    );
  }

  // ── PestRaksh: package plans (choose a plan, then a size) ──────────────────

  /// PestRaksh: the service's packages grouped into plans, or null when the
  /// service has no plans or its data is incomplete; it then keeps the
  /// vendor's list.
  PackagePlanGroups<Variants>? get _planGroups => groupPackagePlans(
    widget.product.packagePlans,
    widget.product.variants,
    planKey: (v) => v.planKey ?? '',
    sizeLabel: (v) => v.sizeLabel ?? '',
  );

  /// PestRaksh: what a package costs: its sale price when it has one, else
  /// its price. The detail model's copy of `packageEffectivePrice`, which is
  /// written for the list model's `Variants`.
  static double _packagePrice(Variants v) {
    final price = v.price ?? 0;
    final sale = v.discountedPrice ?? 0;
    return sale > 0 && sale < price ? sale : price;
  }

  String _money(double amount) =>
      '${widget.product.currency ?? ''}'
      '${amount.formatPrice(widget.product.decimalPoint ?? 2)}';

  /// PestRaksh: selects package [v] by its index in `product.variants`, so the
  /// price, the "Package:" line and ADD follow it. The axis values are set
  /// first, as the vendor's list does, so the cubit's attribute selection
  /// stays in step; `selectVariant` then pins the exact package, because
  /// packages in different plans can share the same attribute values and the
  /// axis match alone would land on the first plan's.
  void _selectPackage(Variants v) {
    final variants = widget.product.variants ?? const <Variants>[];
    final index = variants.indexWhere((x) => identical(x, v));
    if (index < 0 || index == widget.selectedVariantIndex) return;
    // PestRaksh: one step. Selecting each attribute first emitted once per
    // attribute, and every emit reloads Similar services; with plans shown
    // the attribute chips are hidden, so only the index matters.
    context.read<ProductDetailCubit>().selectVariant(index);
  }

  /// PestRaksh: the website's PackagePlanPicker: plan cards (only with two or
  /// more plans), the plan's description, then one button per size.
  Widget _packagePlanPicker(PackagePlanGroups<Variants> groups) {
    final variants = widget.product.variants ?? const <Variants>[];
    final selected = variants.isEmpty
        ? null
        : variants[widget.selectedVariantIndex.clamp(0, variants.length - 1)];
    final activePlan = groups.planOf(selected, (v) => v.planKey ?? '');
    final showPlans = groups.plans.length > 1;
    final headingStyle = context.tt.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: context.cs.onSurfaceVariant,
      letterSpacing: 0.5,
    );
    final sizeHeading = groups.sizeHeading.isNotEmpty
        ? groups.sizeHeading
        : context.translate(LanguageLabelKeys.chooseSize);
    // As on the website: three sizes a row, two when a label is long
    // ("1,001 to 2,000 sq ft").
    final longSizes = activePlan.variants.any(
      (v) => (v.sizeLabel ?? '').trim().length > 10,
    );

    return Column(
      crossAxisAlignment: .start,
      children: [
        if (showPlans) ...[
          AppText(LanguageLabelKeys.choosePlan, style: headingStyle),
          AppSpacing.h8,
          _gridWrap(
            columns: 2,
            children: [
              for (final plan in groups.plans)
                _planCard(plan, plan.key == activePlan.key, selected),
            ],
          ),
          AppSpacing.h12,
        ],
        if (activePlan.description.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
            decoration: AppDecorations.box(
              color: context.cs.surface,
              borderRadius: AppRadius.r12,
              border: Border.all(color: context.cs.outlineVariant),
            ),
            child: Text.rich(
              TextSpan(
                text: showPlans
                    ? '${activePlan.name}: '
                    : '${context.translate(LanguageLabelKeys.planIncludes)}: ',
                style: context.tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: activePlan.description,
                    style: context.tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: context.cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.h12,
        ],
        AppText(sizeHeading, style: headingStyle),
        AppSpacing.h8,
        _gridWrap(
          columns: longSizes ? 2 : 3,
          children: [
            for (final v in activePlan.variants)
              _sizeButton(v, identical(v, selected)),
          ],
        ),
      ],
    );
  }

  /// PestRaksh: a [Wrap] whose children share the row equally, so cards line
  /// up in columns and still fit narrow phones.
  Widget _gridWrap({required int columns, required List<Widget> children}) {
    const gap = ThemeConstants.spaceS;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }

  BoxDecoration _optionDecoration({
    required bool selected,
    bool disabled = false,
  }) => AppDecorations.box(
    color: selected
        ? context.cs.primary.withValues(alpha: 0.08)
        : context.cs.surface,
    borderRadius: AppRadius.r12,
    border: Border.all(
      color: selected
          ? context.cs.primary
          : disabled
          ? context.cs.outlineVariant.withValues(alpha: 0.3)
          : context.cs.outlineVariant,
      width: selected ? 1.5 : 1.0,
    ),
  );

  /// PestRaksh: one plan: its name and lowest price, "From" when its sizes
  /// differ in price. Tapping keeps the customer's size (2 BHK stays 2 BHK).
  Widget _planCard(
    PackagePlan<Variants> plan,
    bool active,
    Variants? selected,
  ) {
    final prices = [
      for (final v in plan.variants)
        if (_packagePrice(v) > 0) _packagePrice(v),
    ];
    final low = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
    final from = prices.toSet().length > 1;
    return InkWell(
      borderRadius: AppRadius.r12,
      onTap: active
          ? null
          : () => _selectPackage(
              samePackageSizeIn(
                plan,
                selected,
                (v) => v.sizeLabel ?? '',
                // PestRaksh: prefer a size that can be booked.
                isAvailable: (v) => v.inStock != false,
              ),
            ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        decoration: _optionDecoration(selected: active),
        child: Column(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceXS,
          children: [
            AppText(
              plan.name,
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? context.cs.primary : context.cs.onSurface,
                height: 1.3,
              ),
            ),
            if (low != null)
              Text.rich(
                TextSpan(
                  text: from
                      ? '${context.translate(LanguageLabelKeys.fromPrice)} '
                      : '',
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: _money(low),
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// PestRaksh: one size with its price, the old price struck through when
  /// on sale. Out of stock looks disabled and can't be picked, as in the
  /// vendor's list.
  Widget _sizeButton(Variants v, bool selected) {
    final disabled = v.inStock == false;
    final raw = v.price ?? 0;
    final price = _packagePrice(v);
    final fg = disabled
        ? context.cs.onSurface.withValues(alpha: 0.38)
        : selected
        ? context.cs.primary
        : context.cs.onSurface;
    return InkWell(
      borderRadius: AppRadius.r12,
      onTap: disabled || selected ? null : () => _selectPackage(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXS,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: _optionDecoration(selected: selected, disabled: disabled),
        child: Column(
          spacing: ThemeConstants.spaceXXS,
          children: [
            AppText(
              (v.sizeLabel ?? '').trim(),
              textAlign: .center,
              maxLines: 2,
              overflow: .ellipsis,
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.25,
              ),
            ),
            AppText(
              _money(price),
              textAlign: .center,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (price < raw)
              AppText(
                _money(raw),
                textAlign: .center,
                maxLines: 1,
                overflow: .ellipsis,
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant.withValues(
                    alpha: disabled ? 0.38 : 1,
                  ),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: context.cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleKeyFeatures() {
    setState(() => _showKeyFeatures = !_showKeyFeatures);
    if (_showKeyFeatures) {
      _slideCtrl.forward();
    } else {
      _slideCtrl.reverse();
    }
  }

  bool _isVariantCombinationAvailable(
    int attributeId,
    int attributeValueId,
    Map<int, int> currentSelection,
  ) {
    final variants = widget.product.variants ?? [];
    if (variants.isEmpty) return true;

    final testSelection = Map<int, int>.from(currentSelection);
    testSelection[attributeId] = attributeValueId;

    for (final variant in variants) {
      bool matches = true;
      for (final entry in testSelection.entries) {
        final hasAttribute = (variant.attributes ?? []).any(
          (attr) =>
              attr.attributeId == entry.key &&
              attr.attributeValueId == entry.value,
        );
        if (!hasAttribute) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final sh = context.screenHeight;
    final (heroMemCacheWidth, heroMemCacheHeight) = productHeroMemCacheSize(
      context,
    );
    final variants = widget.product.variants ?? [];
    final safeIndex = widget.selectedVariantIndex.clamp(
      0,
      variants.isEmpty ? 0 : variants.length - 1,
    );

    final displayShortDesc = widget.product.shortDescription ?? '';
    final displayDesc = widget.product.description ?? '';

    final activeVariant = variants.isNotEmpty ? variants[safeIndex] : null;
    // PestRaksh: a service with package plans shows "choose a plan, then a
    // size" in place of the vendor's variant list; null keeps that list.
    final planGroups = _planGroups;
    // PestRaksh: the title is the service ("Cockroach Control"), as on the
    // website; the package name only stands in when the service has none.
    final displayName =
        (widget.product.name?.isNotEmpty == true
            ? widget.product.name
            : activeVariant?.name) ??
        '';
    // PestRaksh: the selected package goes on its own "Package: …" line
    // under the title, skipped when it is empty or already the title.
    final packageName = activeVariant?.name ?? '';
    final showPackageLine =
        packageName.isNotEmpty && packageName != displayName;
    final variantImages =
        activeVariant?.images
            ?.map((i) => i.imageUrl ?? '')
            .where((u) => u.isNotEmpty)
            .toList() ??
        [];
    final allImages = variantImages.isNotEmpty
        ? variantImages
        : (widget.product.imageUrl?.isNotEmpty == true
              ? [widget.product.imageUrl!]
              : <String>[]);

    return CustomScrollView(
      controller: widget.scrollController,
      // Widen (not unbound — this page can carry many review images/similar
      // products, so an infinite cache risks building the whole page
      // eagerly) the cache window so the upsell section stays mounted at
      // typical scroll depths; otherwise its GlobalKey.currentContext goes
      // null and silently breaks Scrollable.ensureVisible.
      scrollCacheExtent: const ScrollCacheExtent.pixels(6000),
      slivers: [
        // ── App bar + image ────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          expandedHeight: sh * 0.38,
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: widget.isCollapsed
              ? context.cs.surface
              : Colors.transparent,
          foregroundColor: context.cs.onSurface,
          elevation: widget.isCollapsed ? 0.5 : 0,
          shadowColor: context.theme.shadowColor.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          title: AnimatedOpacity(
            opacity: widget.isCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AppText(
              displayName,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
            child: ProductDetailCircleBtn(
              icon: widget.isExpanded
                  ? AssetsConstants.arrowDownIcon
                  : AssetsConstants.arrowUpIcon,
              onTap: widget.onToggleExpand,
              isActive: widget.isCollapsed,
            ),
          ),
          actions: [
            ProductDetailShareBtn(
              product: widget.product,
              isActive: widget.isCollapsed,
            ),
            AppSpacing.w4,
            ProductDetailFavBtn(
              product: widget.product,
              isActive: widget.isCollapsed,
            ),
            AppSpacing.w8,
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Hero(
              tag: 'product_hero_${widget.productId}${widget.heroSuffix}',
              child: Container(
                color: context.cs.surfaceContainerHigh,
                child: Stack(
                  children: [
                    allImages.isNotEmpty
                        ? GestureDetector(
                            onTap: () => AppNavigator.pushNamed(
                              context,
                              RouteNames.fullScreenImageViewer,
                              arguments: (allImages, widget.imagePage, true),
                            ),
                            child: PageView.builder(
                              controller: widget.imageController,
                              itemCount: allImages.length,
                              onPageChanged: widget.onImagePageChanged,
                              itemBuilder: (_, i) {
                                final initialUrl = widget.initialImageUrl;
                                final placeholder =
                                    i == 0 &&
                                        initialUrl != null &&
                                        initialUrl.isNotEmpty &&
                                        initialUrl != allImages[i]
                                    ? AppNetworkImage(
                                        url: initialUrl,
                                        fit: BoxFit.contain,
                                        memCacheWidth: heroMemCacheWidth,
                                        memCacheHeight: heroMemCacheHeight,
                                      )
                                    : null;
                                // Taps fall through to the GestureDetector
                                // above, which opens the full-screen viewer.
                                if (isVideoUrl(allImages[i])) {
                                  return AppNetworkVideo(
                                    url: allImages[i],
                                    play: i == widget.imagePage,
                                    placeholder: placeholder,
                                  );
                                }
                                return AppNetworkImage(
                                  url: allImages[i],
                                  fit: BoxFit.contain,
                                  memCacheWidth: heroMemCacheWidth,
                                  memCacheHeight: heroMemCacheHeight,
                                  placeholder: placeholder,
                                );
                              },
                            ),
                          )
                        : const AppNetworkImage(url: ''),
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      top: 0,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Container(
                          width: 160,
                          decoration: AppDecorations.box(
                            color: context.cs.scrim.withValues(alpha: 0.75),
                          ),
                          padding: const EdgeInsetsDirectional.all(
                            ThemeConstants.paddingM,
                          ),
                          child: Column(
                            crossAxisAlignment: .start,
                            mainAxisAlignment: .end,
                            children: [
                              AppText(
                                context.translate(
                                  LanguageLabelKeys.keyFeatures,
                                ),
                                style: context.tt.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              AppSpacing.h10,
                              if (widget.product.categoryName?.isNotEmpty ==
                                  true) ...[
                                AppText(
                                  context.translate(LanguageLabelKeys.category),
                                  style: context.tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                AppText(
                                  widget.product.categoryName!,
                                  style: context.tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                ),
                                AppSpacing.h8,
                              ],
                              if (widget.product.brandName?.isNotEmpty ==
                                  true) ...[
                                AppText(
                                  context.translate(LanguageLabelKeys.brand),
                                  style: context.tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                AppText(
                                  widget.product.brandName!,
                                  style: context.tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                ),
                                AppSpacing.h8,
                              ],
                              if (widget.product.madeIn?.isNotEmpty ==
                                  true) ...[
                                AppText(
                                  context.translate(LanguageLabelKeys.madeIn),
                                  style: context.tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                AppText(
                                  widget.product.madeIn!,
                                  style: context.tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                ),
                                AppSpacing.h8,
                              ],
                              if (widget.product.branchName?.isNotEmpty ==
                                  true) ...[
                                AppText(
                                  context.translate(LanguageLabelKeys.soldBy),
                                  style: context.tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                AppText(
                                  widget.product.branchName!,
                                  style: context.tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (context, child) {
                        final arrowInset = 160 + (_slideAnim.value.dx * 160);
                        return PositionedDirectional(
                          start: arrowInset,
                          bottom: 50,
                          height: 40,
                          width: 24,
                          child: child!,
                        );
                      },
                      child: GestureDetector(
                        onTap: _toggleKeyFeatures,
                        child: Container(
                          decoration: AppDecorations.box(
                            color: context.cs.scrim.withValues(alpha: 0.8),
                            borderRadius: const BorderRadiusDirectional.only(
                              topEnd: Radius.circular(4),
                              bottomEnd: Radius.circular(4),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Transform.flip(
                            flipX:
                                Directionality.of(context) == TextDirection.rtl,
                            child: AppSvgIcon(
                              _showKeyFeatures
                                  ? AssetsConstants.arrowLeftIcon
                                  : AssetsConstants.arrowRightIcon,
                              color: Colors.white,
                              bakeTint: true,
                              size: ThemeConstants.iconXS,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (allImages.length > 1)
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: .center,
                          children: List.generate(allImages.length, (i) {
                            final active = i == widget.imagePage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: active ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsetsDirectional.symmetric(
                                horizontal: 2,
                              ),
                              decoration: AppDecorations.box(
                                color: active
                                    ? context.cs.primary
                                    : context.cs.outlineVariant,
                                borderRadius: AppRadius.r4,
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: ColoredBox(
            color: context.theme.scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                // ── Name + meta ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingL,
                    ThemeConstants.paddingM,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BlocBuilder<
                        RatingsListCubit,
                        PaginationState<ProductRatingList>
                      >(
                        builder: (context, rState) {
                          final loaded =
                              rState is PaginationLoaded<ProductRatingList>;
                          final summary = context
                              .read<RatingsListCubit>()
                              .summary;
                          final avg = loaded
                              ? double.tryParse(summary.averageRating ?? '0') ??
                                    0.0
                              : 0.0;
                          final total = loaded
                              ? (int.tryParse(summary.oneStarRating ?? '0') ??
                                        0) +
                                    (int.tryParse(
                                          summary.twoStarRating ?? '0',
                                        ) ??
                                        0) +
                                    (int.tryParse(
                                          summary.threeStarRating ?? '0',
                                        ) ??
                                        0) +
                                    (int.tryParse(
                                          summary.fourStarRating ?? '0',
                                        ) ??
                                        0) +
                                    (int.tryParse(
                                          summary.fiveStarRating ?? '0',
                                        ) ??
                                        0)
                              : 0;
                          final hasTime =
                              widget.product.timeToDeliver?.isNotEmpty == true;
                          return Row(
                            spacing: ThemeConstants.spaceS,
                            children: [
                              if (widget.product.productType != 0) ...[
                                ProductTypeIcon(
                                  productType: widget.product.productType,
                                  size: ThemeConstants.iconXS,
                                ),
                                if (hasTime)
                                  Container(
                                    width: 1,
                                    height: 12,
                                    color: context.cs.outlineVariant,
                                  ),
                              ],
                              if (hasTime)
                                Row(
                                  mainAxisSize: .min,
                                  spacing: ThemeConstants.spaceXS,
                                  children: [
                                    const DeliveryTimeIcon(
                                      size: ThemeConstants.iconXS,
                                    ),
                                    AppText(
                                      widget.product.timeToDeliver!,
                                      style: context.tt.bodySmall?.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: context.cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              if (total > 0 &&
                                  (hasTime || widget.product.productType != 0))
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: context.cs.outlineVariant,
                                ),
                              if (total > 0)
                                Row(
                                  mainAxisSize: .min,
                                  spacing: ThemeConstants.spaceXS,
                                  children: [
                                    StarRatingRow(
                                      rating: avg,
                                      size: ThemeConstants.iconXXS,
                                    ),
                                    AppText(
                                      '($total)',
                                      style: context.tt.bodySmall?.copyWith(
                                        color: context.cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                      AppSpacing.h8,
                      AppText(
                        displayName,
                        style: context.tt.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                          height: 1.3,
                        ),
                      ),
                      // PestRaksh: "Package: 1 BHK (Single Service)", as on
                      // the website; it changes when another package is picked.
                      if (showPackageLine) ...[
                        AppSpacing.h4,
                        Text.rich(
                          TextSpan(
                            text:
                                '${context.translate(LanguageLabelKeys.packageLabel)} ',
                            style: context.tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: context.cs.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text: packageName,
                                style: context.tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (displayShortDesc.isNotEmpty) ...[
                        AppSpacing.h6,
                        AppText(
                          displayShortDesc,
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: .ellipsis,
                        ),
                      ],
                      if (widget.product.productType == 5 &&
                          (widget.product.prescriptionNote?.isNotEmpty ==
                              true)) ...[
                        AppSpacing.h10,
                        _PrescriptionBanner(
                          note: widget.product.prescriptionNote!,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── PestRaksh: package plans (choose a plan, then a size) ────
                if (planGroups != null) ...[
                  _ThinDivider(),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingM,
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingS,
                    ),
                    child: _packagePlanPicker(planGroups),
                  ),
                ],

                // ── Add-on product: variants as single choice, sheet style ───
                if (planGroups == null && _showAddonVariantCard) ...[
                  _ThinDivider(),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingS,
                      ThemeConstants.paddingL,
                      0,
                    ),
                    child: AddonCard(
                      title: _addonVariantTitle,
                      children: [
                        for (
                          var i = 0;
                          i < (widget.product.variants ?? []).length;
                          i++
                        )
                          _addonVariantRow(i),
                      ],
                    ),
                  ),
                ],

                // ── Variant axes ─────────────────────────────────────────────
                if (planGroups == null &&
                    !_showAddonVariantCard &&
                    (widget.product.variantAxes ?? []).isNotEmpty) ...[
                  _ThinDivider(),
                  ...((widget.product.variantAxes ?? []).map((axis) {
                    final selectedValueId =
                        widget.selectedAxisValues[axis.attributeId];
                    return Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ThemeConstants.paddingL,
                        ThemeConstants.paddingXS,
                        0,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          AppText(
                            axis.attributeName ?? '',
                            style: context.tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          AppSpacing.h8,
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: (axis.values ?? []).map((val) {
                                final isSel =
                                    selectedValueId == val.attributeValueId;
                                final isAvailable =
                                    _isVariantCombinationAvailable(
                                      axis.attributeId!,
                                      val.attributeValueId!,
                                      widget.selectedAxisValues,
                                    );
                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: ThemeConstants.paddingS,
                                  ),
                                  child: GestureDetector(
                                    onTap: isAvailable
                                        ? () => context
                                              .read<ProductDetailCubit>()
                                              .selectAxisValue(
                                                axis.attributeId!,
                                                val.attributeValueId!,
                                              )
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding:
                                          const EdgeInsetsDirectional.symmetric(
                                            horizontal: ThemeConstants.paddingS,
                                            vertical: ThemeConstants.paddingXS,
                                          ),
                                      decoration: AppDecorations.box(
                                        color: isSel
                                            ? context.cs.primary.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.transparent,
                                        borderRadius: AppRadius.r8,
                                        border: Border.all(
                                          color: isSel
                                              ? context.cs.primary
                                              : isAvailable
                                              ? context.cs.outlineVariant
                                              : context.cs.outlineVariant
                                                    .withValues(alpha: 0.3),
                                          width: isSel ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: AppText(
                                        val.attributeValue ?? '',
                                        style: context.tt.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: isSel
                                              ? context.cs.primary
                                              : isAvailable
                                              ? context.cs.onSurface
                                              : context.cs.onSurfaceVariant
                                                    .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          AppSpacing.h6,
                        ],
                      ),
                    );
                  })),
                ],

                // ── Add-ons (under the variants) ─────────────────────────────
                if (widget.addonController != null &&
                    widget.product.requiresAddonSheet) ...[
                  _ThinDivider(),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingS,
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingS,
                    ),
                    child: AddonGroupsSection(
                      controller: widget.addonController!,
                      currency: widget.product.currency ?? '',
                      decimalPoint: widget.product.decimalPoint ?? 2,
                    ),
                  ),
                ],

                // ── Policies ──────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingL,
                    vertical: ThemeConstants.paddingS,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingM,
                    vertical: ThemeConstants.paddingS,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: AppDecorations.box(
                    color: context.cs.surface,
                    borderRadius: AppRadius.r12,
                    boxShadow: [
                      BoxShadow(
                        color: context.cs.shadow.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ProductDetailPoliciesSection(
                    product: widget.product,
                    // PestRaksh: its warranty shows in the first tile.
                    selectedVariant: activeVariant,
                  ),
                ),

                // ── Pincode delivery check ───────────────────────────────────
                if (SettingsHiveBox.instance.channel ==
                        AppConstants.ecommerce &&
                    widget.product.isPincodeCheckAvailable &&
                    activeVariant?.id != null) ...[
                  ProductPincodeCheckSection(
                    variantId: activeVariant!.id.toString(),
                  ),
                ],

                // ── Delivery by ──────────────────────────────────────────────
                if (SettingsHiveBox.instance.channel != AppConstants.quick &&
                    (widget.product.estimatedDeliveryDate?.isNotEmpty ==
                        true)) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                      vertical: ThemeConstants.paddingS,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: ThemeConstants.paddingM,
                      ),
                      decoration: AppDecorations.box(
                        color: context.cs.surface,
                        borderRadius: AppRadius.r12,
                        boxShadow: [
                          BoxShadow(
                            color: context.cs.shadow.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: .min,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          AppSvgIcon(
                            AssetsConstants.expectedDeliveryIcon,
                            size: ThemeConstants.iconS,
                            color: context.cs.onSurface,
                            bakeTint: true,
                          ),
                          Text.rich(
                            TextSpan(
                              text:
                                  '${context.translate(LanguageLabelKeys.deliveryBy)} ',
                              style: context.tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: context.cs.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: AppDateFormatter.formatDate(
                                    widget.product.estimatedDeliveryDate,
                                  ),
                                  style: context.tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Product Details / long description + custom sections ───────
                // All shown as one card, sections separated by a thin divider.
                Builder(
                  builder: (context) {
                    final List<Widget> entries = [];

                    if (displayDesc.isNotEmpty && displayDesc != 'null') {
                      entries.add(
                        _ExpandableSection(
                          title: context.translate(
                            LanguageLabelKeys.productInfo,
                          ),
                          child: HtmlWidget(
                            displayDesc,
                            textStyle: context.tt.bodyMedium?.copyWith(
                              color: context.cs.onSurfaceVariant,
                              height: 1.7,
                            ),
                          ),
                        ),
                      );
                    }

                    for (final section
                        in (activeVariant?.customSections ?? [])) {
                      if (section.fields?.isNotEmpty != true) continue;
                      final textFields = (section.fields ?? [])
                          .where(
                            (f) =>
                                f.fieldType != 'image' &&
                                f.value?.isNotEmpty == true &&
                                f.value != 'null',
                          )
                          .toList();
                      final imageFields = (section.fields ?? [])
                          .where(
                            (f) =>
                                f.fieldType == 'image' &&
                                f.value?.isNotEmpty == true &&
                                f.value != 'null',
                          )
                          .toList();
                      if (textFields.isEmpty && imageFields.isEmpty) continue;

                      if (textFields.isNotEmpty) {
                        entries.add(
                          _ExpandableSection(
                            title: section.sectionName ?? '',
                            child: Column(
                              children: List.generate(textFields.length, (i) {
                                final field = textFields[i];
                                final isEven = i.isEven;
                                return Container(
                                  decoration: AppDecorations.box(
                                    color: isEven
                                        ? context.cs.surfaceContainerLow
                                        : context.cs.surfaceContainerLow
                                              .withValues(alpha: 0.3),
                                    border: Border.all(
                                      color: context.cs.surfaceContainerLow,
                                    ),
                                  ),
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: ThemeConstants.paddingS,
                                        vertical: ThemeConstants.paddingS,
                                      ),
                                  child: Row(
                                    crossAxisAlignment: .start,
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        child: AppText(
                                          field.fieldLabel ?? '',
                                          style: context.tt.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: context.cs.onSurface,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: AppText(
                                          field.value!,
                                          style: context.tt.bodySmall?.copyWith(
                                            color: context.cs.onSurfaceVariant,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }

                      if (imageFields.isNotEmpty) {
                        entries.add(
                          Column(
                            crossAxisAlignment: .start,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  ThemeConstants.paddingM,
                                  ThemeConstants.paddingM,
                                  ThemeConstants.paddingM,
                                  ThemeConstants.paddingXS,
                                ),
                                child: AppText(
                                  section.sectionName ?? '',
                                  style: context.tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.cs.onSurface,
                                  ),
                                ),
                              ),
                              ...imageFields.map(
                                (field) => Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    ThemeConstants.paddingM,
                                    ThemeConstants.paddingM,
                                    ThemeConstants.paddingM,
                                    ThemeConstants.paddingM,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      if (field.fieldLabel?.isNotEmpty ==
                                          true) ...[
                                        AppText(
                                          field.fieldLabel!,
                                          style: context.tt.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: context.cs.onSurfaceVariant,
                                          ),
                                        ),
                                        AppSpacing.h8,
                                      ],
                                      ClipRRect(
                                        borderRadius: AppRadius.r8,
                                        child: AppNetworkImage(
                                          url: field.value!,
                                          height: context.screenHeight * 0.21,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    if (entries.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingL,
                        vertical: ThemeConstants.paddingS,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: AppDecorations.box(
                        color: context.cs.surface,
                        borderRadius: AppRadius.r12,
                        boxShadow: [
                          BoxShadow(
                            color: context.cs.shadow.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: ThemeConstants.paddingXS,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < entries.length; i++) ...[
                              entries[i],
                              if (i != entries.length - 1) _ThinDivider(),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Below-the-fold sections each get their own sliver instead of
        // sitting in the Column above: the viewport skips painting slivers
        // outside the visible + cache area, so a peeking card (and its
        // swiped neighbours) no longer re-rasterizes ratings and product
        // card lists nobody can see on every frame of a swipe.
        // ── Ratings ───────────────────────────────────────────────────
        _DetailSectionSliver(
          child: ProductDetailRatingSection(
            productRating: widget.product.productRating,
          ),
        ),

        // ── Upsell, similar & recently visited ──────────────────────────
        _DetailSectionSliver(
          child: ProductDetailUpsellSection(
            sectionKey: widget.upsellSectionKey,
            heroSuffix: '${widget.subSectionHeroSuffix}_upsell',
          ),
        ),
        _DetailSectionSliver(
          child: SimilarProductsSection(
            sectionKey: widget.similarSectionKey,
            heroSuffix: '${widget.subSectionHeroSuffix}_sp',
          ),
        ),
        _DetailSectionSliver(
          child: RecentlyVisitedSection(
            sectionKey: widget.recentlyVisitedSectionKey,
            heroSuffix: '${widget.subSectionHeroSuffix}_rv',
          ),
        ),
        // ProductDetailBottomBar floats over content (AppScaffold's
        // applyBottomInset: false here), and FloatingCartBar floats
        // above that bar in turn (52px pill + 10px own bottom
        // padding) — reserve clearance for both so the last section
        // (and its "View more" button) never sits underneath either.
        const _DetailSectionSliver(child: SizedBox(height: 100 + 85)),
      ],
    );
  }
}

// ── Local widgets ───────────────────────────────────────────────────────────

/// One below-the-fold section as its own sliver, on the same scaffold
/// background, keeping the start-aligned, loose-width layout it had as a
/// child of the main content Column.
class _DetailSectionSliver extends StatelessWidget {
  final Widget child;

  const _DetailSectionSliver({required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ColoredBox(
        color: context.theme.scaffoldBackgroundColor,
        child: Column(crossAxisAlignment: .start, children: [child]),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final Widget child;

  const _ExpandableSection({required this.title, required this.child});

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingM,
              vertical: ThemeConstants.paddingM,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    widget.title,
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AppSvgIcon(
                    AssetsConstants.arrowDownIcon,
                    size: ThemeConstants.iconM,
                    color: context.cs.onSurfaceVariant,
                    bakeTint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingM,
              0,
              ThemeConstants.paddingM,
              ThemeConstants.paddingM,
            ),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}

class _PrescriptionBanner extends StatelessWidget {
  final String note;
  const _PrescriptionBanner({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingM,
        vertical: ThemeConstants.paddingS,
      ),
      decoration: AppDecorations.box(
        color: context.cs.inversePrimary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r8,
        border: Border.all(
          color: context.cs.inversePrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceS,
        children: [
          AppSvgIcon(
            AssetsConstants.infoCircleIcon,
            size: ThemeConstants.iconXS,
            color: context.cs.inversePrimary,
            bakeTint: true,
          ),
          Expanded(
            child: AppText(
              note,
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.inversePrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
