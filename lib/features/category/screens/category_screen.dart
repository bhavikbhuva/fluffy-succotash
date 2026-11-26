import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/cubit/location_cubit.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/category/cubit/category_layout_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_layout_model.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/features/home/models/enums/background_theme_type.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/utils/home_hex_color.dart';
import 'package:customer/features/home/widgets/section_widget.dart';
import 'package:customer/features/home/widgets/skeleton_loader.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Categories screen designed in the panel's Category Builder
/// (customer/category_layout): a header-painted top bar plus the same
/// sections home renders. Category taps open the subcategory screens.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  // Built once per section object so a load-more rebuild skips sections
  // already on screen; cleared when a reload brings a new layout.
  final Map<Sections, Widget> _sectionWidgets = {};
  CategoryLayoutModel? _renderedLayout;

  static const double _kLoadMoreTriggerFraction = 0.7;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SettingsHiveBox.instance.channelListenable.addListener(_onChannelChanged);
    context.read<CategoryLayoutCubit>().loadCategoryLayout();
  }

  @override
  void dispose() {
    SettingsHiveBox.instance.channelListenable.removeListener(
      _onChannelChanged,
    );
    _scrollController.dispose();
    super.dispose();
  }

  // Quick and ecommerce can serve different categories in the same city.
  void _onChannelChanged() =>
      context.read<CategoryLayoutCubit>().reloadIfChannelChanged();

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0 &&
        _scrollController.offset >= maxExtent * _kLoadMoreTriggerFraction) {
      context.read<CategoryLayoutCubit>().loadMoreSections();
    }
  }

  void _onCategoryTap(BuildContext context, Category category) {
    if (category.hasChild == true) {
      AppNavigator.push(
        context,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  SubCategoryCubit(parentCategoryId: category.id ?? ''),
            ),
            BlocProvider(create: (_) => SubCategorySelectionCubit()),
            BlocProvider(create: (_) => SubCategoryChildrenCubit()),
            BlocProvider(create: (_) => ProductCubit()),
            BlocProvider(create: (_) => FilterCubit()),
          ],
          child: SubCategoryScreen(parentCategory: category),
        ),
      );
    } else {
      AppNavigator.push(
        context,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  ProductCubit()..loadProducts(categoryId: category.id ?? ''),
            ),
            BlocProvider(
              create: (_) =>
                  FilterCubit()..loadFilters(categoryId: category.id ?? ''),
            ),
          ],
          child: SubCategoryScreen(
            parentCategory: category,
            showSidebar: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, int>(
      listener: (context, state) =>
          context.read<CategoryLayoutCubit>().loadCategoryLayout(),
      child: BlocConsumer<ConnectivityCubit, ConnectivityState>(
        listener: (context, state) {
          if (state is ConnectivityConnected) {
            context.read<CategoryLayoutCubit>().loadCategoryLayout();
          }
        },
        builder: (context, connectivityState) {
          return BlocBuilder<CategoryLayoutCubit, CategoryLayoutState>(
            builder: (context, state) {
              final header = state is CategoryLayoutLoaded
                  ? state.categoryLayout.data?.layout?.header
                  : null;
              return AppScaffold(
                applyBottomInset: false,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: _CategoryHeaderAppBar(
                  title: context.translate(LanguageLabelKeys.categories),
                  header: header,
                  scrollController: _scrollController,
                ),
                // Offline lives in the body so the app bar (and its back
                // button on the pushed-route variant) stays usable.
                body: connectivityState is ConnectivityDisconnected
                    ? const AppNoInternetView()
                    : _buildBody(context, state),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CategoryLayoutState state) {
    if (state is CategoryLayoutInitial || state is CategoryLayoutLoading) {
      return const SingleChildScrollView(child: SkeletonLoader());
    }
    if (state is CategoryLayoutError) {
      return Center(
        child: EmptyStateWidget(
          imagePath: AssetsConstants.noSearchFound,
          title: state.message,
          subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
          onRetry: () => context.read<CategoryLayoutCubit>().loadCategoryLayout(
            emitLoadingState: true,
          ),
        ),
      );
    }
    if (state is CategoryLayoutLoaded) {
      if (!identical(_renderedLayout, state.categoryLayout)) {
        _renderedLayout = state.categoryLayout;
        _sectionWidgets.clear();
      }
      final sections = state.categoryLayout.data?.layout?.sections ?? [];
      return RefreshIndicator(
        color: context.cs.primary,
        // Sections stay on screen; the spinner ends when the new layout
        // lands.
        onRefresh: () =>
            context.read<CategoryLayoutCubit>().loadCategoryLayout(),
        child: sections.isEmpty
            ? _buildEmpty(context)
            : _buildSections(
                context,
                sections,
                isLoadingMore: state.isLoadingMore,
              ),
      );
    }
    return const SizedBox.shrink();
  }

  // Scrollable so pull-to-refresh still works on an empty layout.
  Widget _buildEmpty(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyStateWidget(
              imagePath: AssetsConstants.noSearchFound,
              title: context.translate(LanguageLabelKeys.noCategoriesFound),
              subtitle: context.translate(LanguageLabelKeys.categoriesEmpty),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSections(
    BuildContext context,
    List<Sections> sections, {
    bool isLoadingMore = false,
  }) {
    final footer = <Widget>[
      if (isLoadingMore) const SkeletonLoader(),
      // Clears the bottom nav, plus the safe-area inset when the floating
      // cart bar sits above it.
      BlocBuilder<CartCubit, CartState>(
        buildWhen: (prev, curr) =>
            (prev.totalItems > 0) != (curr.totalItems > 0),
        builder: (context, cartState) => SizedBox(
          height:
              ThemeConstants.bottomBarHeight +
              (cartState.totalItems > 0
                  ? context.bottomSafePadding
                  : context.bottomSafePadding / 2),
        ),
      ),
    ];
    // Lazy list: only sections on (or near) screen are built.
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList.builder(
          itemCount: sections.length + footer.length,
          itemBuilder: (_, index) {
            if (index >= sections.length) {
              return footer[index - sections.length];
            }
            final s = sections[index];
            return _sectionWidgets[s] ??= _buildSection(s);
          },
        ),
      ],
    );
  }

  // Taps behave as on home; banner/title/text redirects (multi-category
  // category_id, redirect_title) are handled inside SectionWidget.
  Widget _buildSection(Sections s) {
    return SectionWidget(
      key: ObjectKey(s),
      section: s,
      onCategoryTap: (cat) {
        if (cat.id == null) return;
        _onCategoryTap(
          context,
          Category(
            id: cat.id.toString(),
            name: cat.name,
            imageUrl: cat.imageUrl,
            hasChild: cat.hasChild ?? false,
          ),
        );
      },
      onProductTap: (product) {
        if (product.id != null) {
          AppNavigator.pushNamed(
            context,
            RouteNames.productDetail,
            arguments: product.id,
          );
        }
      },
      onBrandTap: (brand) {
        if (brand.id == null) return;
        AppNavigator.push(
          context,
          BlocProvider(
            create: (_) => ProductCubit(),
            child: ProductScreen(
              title: brand.name?.isNotEmpty == true
                  ? brand.name!
                  : context.translate(LanguageLabelKeys.brand),
              brandId: brand.id.toString(),
            ),
          ),
        );
      },
      onViewMoreTap: (title, scope) {
        AppNavigator.push(
          context,
          BlocProvider(
            create: (_) => ProductCubit(),
            child: ProductScreen(
              title: title.isNotEmpty
                  ? title
                  : context.translate(LanguageLabelKeys.products),
              categoryId: scope.categoryIds,
              dataSource: scope.dataSource,
              manualProductIds: scope.manualProductIds,
              scopeBrandIds: scope.brandIds,
              filterMode: scope.filterMode,
              redirectParams: scope.filterParams,
            ),
          ),
        );
      },
    );
  }
}

// Top bar painted from the layout's header: background_theme "image" →
// this device's image as a cover background (background_color shows while
// it loads or if it fails), otherwise background_color. text_color tints
// the title and icons; the title text stays the app's own. A null header
// (still loading, error) keeps the plain theme bar.
class _CategoryHeaderAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final CategoryLayoutHeader? header;
  final ScrollController scrollController;

  const _CategoryHeaderAppBar({
    required this.title,
    required this.header,
    required this.scrollController,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final bgColor = parseHomeHexColor(header?.backgroundColor);
    final fgColor = parseHomeHexColor(header?.textColor);
    final imageUrl =
        BackgroundThemeType.fromRaw(header?.backgroundTheme) ==
            BackgroundThemeType.image
        ? header?.imageUrlFor(isTablet: AppSizes.isTabletDevice)
        : null;

    if (imageUrl == null || imageUrl.isEmpty) {
      return _withStatusBarStyle(
        context,
        bgColor,
        CustomAppBar(
          title: title,
          showBackButton: false,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          scrollController: scrollController,
        ),
      );
    }

    final fallback = ColoredBox(color: bgColor ?? context.cs.surface);
    return _withStatusBarStyle(
      context,
      null,
      Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.cover,
            placeholder: fallback,
            errorWidget: fallback,
          ),
          CustomAppBar(
            title: title,
            showBackButton: false,
            backgroundColor: Colors.transparent,
            foregroundColor: fgColor,
            scrollController: scrollController,
          ),
        ],
      ),
    );
  }

  // AppBar picks status-bar icon brightness from its own background, which
  // is transparent over an image — derive it from the header instead: the
  // bar colour in colour mode, the inverse of text_color over an image.
  Widget _withStatusBarStyle(BuildContext context, Color? bg, Widget child) {
    final fg = parseHomeHexColor(header?.textColor);
    final Brightness? barBrightness = bg != null
        ? ThemeData.estimateBrightnessForColor(bg)
        : fg != null
        ? (ThemeData.estimateBrightnessForColor(fg) == Brightness.light
              ? Brightness.dark
              : Brightness.light)
        : null;
    if (barBrightness == null) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          systemOverlayStyle: barBrightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        ),
      ),
      child: child,
    );
  }
}
