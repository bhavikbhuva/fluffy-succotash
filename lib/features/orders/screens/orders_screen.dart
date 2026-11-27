import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/orders/widgets/order_list_skeleton_loader.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_cubit.dart';
import 'package:customer/features/orders/cubit/completed_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/completed_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_order_cubit.dart';
import 'package:customer/features/orders/cubit/upcoming_visits_cubit.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/ecommerce_order_card.dart';
import 'package:customer/features/orders/widgets/order_card.dart';
import 'package:customer/features/orders/widgets/upcoming_visits_section.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Add-on module: an order item's add-on snapshot as the `{id, qty}`
/// answers to re-add it with — without them a dish with a required group is
/// refused.
List<AddonSelection> _reorderAddons(List<CartAddon>? addons) => [
  for (final a in addons ?? const <CartAddon>[]) ?a.toSelection(),
];

/// Re-adds every item from [order] to the cart in one request via the
/// app-wide [GuestCartSyncCubit] (provided in main.dart) — works for both
/// guest and logged-in users since the bulk-add endpoint resolves the cart
/// by device/session, not strictly by auth token.
void _handleReorder(BuildContext context, OrderData order) {
  final plain = <BulkCartItem>[];
  final withAddons = <BulkCartItem>[];

  for (final item in order.items ?? <OrderItems>[]) {
    final variantId = (item.productVariantId ?? item.variantId)?.toString();
    final qty = item.quantity;
    if (variantId == null || variantId.isEmpty || qty == null || qty <= 0) {
      continue;
    }
    final line = BulkCartItem(
      variantId: variantId,
      qty: qty,
      addons: _reorderAddons(item.addons),
    );
    (line.hasAddons ? withAddons : plain).add(line);
  }

  // Add-on module: the server stops at the first refused line, so add-on
  // lines (whose options may since have gone) go after the plain ones.
  final items = [...plain, ...withAddons];
  if (items.isEmpty) return;

  // PestRaksh: every booking is a Quick booking, so Book Again always fills
  // the Quick cart, even if an old order came back without its channel.
  context.read<GuestCartSyncCubit>().bulkAddItems(quickItems: items);
}

/// Re-adds a single ecommerce order item to the cart.
void _handleReorderEcommerceItem(
  BuildContext context,
  EcommerceOrderDataModel item,
) {
  final variantId = (item.productVariantId ?? item.variantId)?.toString();
  final qty = item.quantity;
  if (variantId == null || variantId.isEmpty || qty == null || qty <= 0) return;

  context.read<GuestCartSyncCubit>().bulkAddItems(
    ecommerceItems: [
      BulkCartItem(
        variantId: variantId,
        qty: qty,
        addons: _reorderAddons(item.addons),
      ),
    ],
  );
}

// PestRaksh: the Quick twin of this check is gone. Book Again shows on every
// booking whatever the active channel, as on the website's My Bookings.
/// Reorder button visibility follows the store's globally active channel
/// (set via the home-screen quick/ecommerce toggle), not the tab currently
/// viewed — so it only appears on the listing matching the live channel.
bool get _showEcommerceReorder =>
    SettingsHiveBox.instance.channel == AppConstants.ecommerce;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Provided app-wide in main.dart (not owned/closed here) — the
  // notification service refetches these directly on "order" pushes even
  // when this screen isn't open, so they must outlive it.
  late final OngoingOrderCubit _ongoingCubit = context
      .read<OngoingOrderCubit>();
  late final CompletedOrderCubit _completedCubit = context
      .read<CompletedOrderCubit>();
  // PestRaksh: every booking is on the Quick channel, so the screen always
  // lists Quick bookings. It no longer follows the active channel (a customer
  // on Shop mode saw an empty list) and has no filter, like the website.
  final _appBarShadow = ValueNotifier<bool>(false);
  // PestRaksh: follow-up visits for the top of Upcoming. Only this screen
  // shows them, so it owns the cubit and closes it.
  final _visitsCubit = UpcomingVisitsCubit();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _appBarShadow.dispose();
    _visitsCubit.close();
    super.dispose();
  }

  void _reload() {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    const filter = OrderFilter(channel: AppConstants.quick);
    _ongoingCubit.applyFilters(filter);
    _completedCubit.applyFilters(filter);
    _visitsCubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GuestCartSyncCubit, GuestCartSyncState>(
          listener: (context, state) {
            if (state is GuestCartSyncSuccess) {
              AppNavigator.pushNamed(context, RouteNames.checkout);
            } else if (state is GuestCartSyncError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.myOrders),
            showBackButton: false,
            shadowListenable: _appBarShadow,
            // PestRaksh: no filter button (Quick/Shop and date range); the
            // website's My Bookings has none.
            bottom: const _PillTabBar(),
          ),
          // PestRaksh: always the Quick lists; the Shop lists are unused.
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: _ongoingCubit),
                  BlocProvider.value(value: _completedCubit),
                  BlocProvider.value(value: _visitsCubit),
                ],
                child: _OngoingOrderList(
                  onScrolledChanged: (v) => _appBarShadow.value = v,
                ),
              ),
              MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: _ongoingCubit),
                  BlocProvider.value(value: _completedCubit),
                ],
                child: _CompletedOrderList(
                  onScrolledChanged: (v) => _appBarShadow.value = v,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _PillTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final containerBg = context.cs.surfaceContainer;
    final unselectedColor = context.cs.onSurfaceVariant;
    final primary = context.cs.primary;

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingS,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
      decoration: AppDecorations.box(
        color: containerBg,
        borderRadius: AppRadius.r20,
      ),
      child: TabBar(
        indicator: AppDecorations.box(
          borderRadius: AppRadius.r16,
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsetsDirectional.zero,
        dividerColor: Colors.transparent,
        labelColor: context.cs.onPrimary,
        unselectedLabelColor: unselectedColor,
        labelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: AppRadius.r16,
        tabs: [
          Tab(height: 44, text: context.translate(LanguageLabelKeys.ongoing)),
          Tab(height: 44, text: context.translate(LanguageLabelKeys.completed)),
        ],
      ),
    );
  }
}

/// Loading/error/empty/paginated-list shell shared by all 4 order-listing
/// tabs (quick + ecommerce, ongoing + completed) — they only differ in which
/// cubit feeds them and how each item card is built.
class _PaginatedOrderList<T> extends StatefulWidget {
  final BasePaginationCubit<T> cubit;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<bool>? onScrolledChanged;

  /// PestRaksh: shown first in the list, scrolling with it (Upcoming's
  /// follow-up visits). When given, it also stands in for the empty state, so
  /// pass it only when it has something to show.
  final Widget? header;

  /// PestRaksh: also run on pull-to-refresh and retry, with the cubit's own
  /// refresh (Upcoming reloads its follow-up visits).
  final Future<void> Function()? onRefresh;

  const _PaginatedOrderList({
    super.key,
    required this.cubit,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onScrolledChanged,
    this.header,
    this.onRefresh,
  });

  @override
  State<_PaginatedOrderList<T>> createState() => _PaginatedOrderListState<T>();
}

class _PaginatedOrderListState<T> extends State<_PaginatedOrderList<T>> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => widget.cubit.fetchMore(),
  );

  // Card widget per item. Every pagination emit (isFetchingMore on/off, page
  // appended) makes ListView rebuild all live children; handing back the
  // identical widget lets Flutter skip those card subtrees. The cubit keeps
  // item identity across emits, and patched items are new objects, so they
  // still rebuild. Reset whenever the parent rebuilds (new itemBuilder).
  Expando<Widget> _cards = Expando();

  @override
  void initState() {
    super.initState();
    _pager.controller.addListener(_notifyScrolled);
  }

  @override
  void didUpdateWidget(covariant _PaginatedOrderList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cards = Expando();
  }

  void _notifyScrolled() {
    widget.onScrolledChanged?.call(
      _pager.controller.hasClients && _pager.controller.offset > 0,
    );
  }

  @override
  void dispose() {
    _pager.controller.removeListener(_notifyScrolled);
    _pager.dispose();
    super.dispose();
  }

  // PestRaksh: the list and the header's own data refresh together.
  Future<void> _refresh() async {
    await Future.wait([widget.cubit.refresh(), ?widget.onRefresh?.call()]);
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final listPadding = EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingS,
      ThemeConstants.paddingL,
      ThemeConstants.paddingL + context.bottomSafePadding,
    );
    return BlocBuilder<BasePaginationCubit<T>, PaginationState<T>>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (state is PaginationLoading<T>) {
          return const OrderListSkeletonLoader();
        }

        if (state is PaginationError<T>) {
          return EmptyStateWidget(
            imagePath: AssetsConstants.noOrderFound,
            title: state.message,
            subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
            onRetry: _refresh,
          );
        }

        if (state is PaginationLoaded<T>) {
          if (state.data.isEmpty) {
            // PestRaksh: with no bookings but a header (follow-up visits),
            // the header shows instead of "no upcoming bookings".
            if (header != null) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: listPadding,
                  children: [header],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    imagePath: AssetsConstants.noOrderFound,
                    title: widget.emptyTitle,
                    subtitle: widget.emptySubtitle,
                  ),
                ],
              ),
            );
          }

          // PestRaksh: the header, when given, is the first row.
          final headerRows = header == null ? 0 : 1;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _pager.attach(
              ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _pager.controller,
                padding: listPadding,
                itemCount:
                    headerRows +
                    state.data.length +
                    (state.isFetchingMore ? 1 : 0),
                itemBuilder: (context, row) {
                  if (header != null && row == 0) return header;
                  final index = row - headerRows;
                  if (index == state.data.length) {
                    return PaginatedListFooter(
                      isLoadingMore: state.isFetchingMore,
                      hasMore: state.hasMore,
                      skeletonBuilder: (_) => const OrderListSkeletonLoader(
                        itemCount: 1,
                        shrinkWrap: true,
                      ),
                    );
                  }
                  final item = state.data[index];
                  return _cards[item as Object] ??= widget.itemBuilder(
                    context,
                    item,
                  );
                },
              ),
            ),
          );
        }

        final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
        return EmptyStateWidget(
          imagePath: AssetsConstants.noOrderFound,
          title: isLoggedIn
              ? widget.emptyTitle
              : context.translate(LanguageLabelKeys.notLoggedInOrdersTitle),
          subtitle: isLoggedIn
              ? widget.emptySubtitle
              : context.translate(LanguageLabelKeys.notLoggedInOrdersSubtitle),
          onRetry: isLoggedIn
              ? null
              : () => AppNavigator.pushNamed(context, RouteNames.login),
          retryLabel: isLoggedIn
              ? LanguageLabelKeys.retry
              : LanguageLabelKeys.login,
        );
      },
    );
  }
}

// ── Ongoing ──────────────────────────────────────────────────────────────────

class _OngoingOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _OngoingOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OngoingOrderCubit>();
    final completedCubit = context.read<CompletedOrderCubit>();
    // PestRaksh: follow-up visits head the Upcoming list. The section goes in
    // only when there are visits, so with none the usual empty state shows.
    final visitsCubit = context.read<UpcomingVisitsCubit>();
    final hasVisits = context.select(
      (UpcomingVisitsCubit c) => c.state.isNotEmpty,
    );
    return _PaginatedOrderList<OrderData>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      header: hasVisits ? const UpcomingVisitsSection() : null,
      onRefresh: visitsCubit.load,
      emptyTitle: context.translate(LanguageLabelKeys.noOngoingOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, order) => OrderCard(
        order: order,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.orderDetail,
            arguments: OrderDetailArgs(
              orderId: order.id?.toString() ?? '',
              isOngoing: true,
            ),
          );
          if (result is OrderData && context.mounted) {
            cubit.removeOrder(result.id?.toString() ?? '');
            completedCubit.addOrder(result);
          }
          // PestRaksh: the booking's page may have changed its visits.
          visitsCubit.load();
        },
        onTrack: () => AppNavigator.pushNamed(
          context,
          RouteNames.orderTracking,
          arguments: order,
        ),
        // PestRaksh: Book Again fills the Quick cart, and checkout shows the
        // cart of the active channel, so the button shows only in Quick mode
        // (once the zone is Quick only, always).
        onReorder: SettingsHiveBox.instance.channel == AppConstants.quick
            ? () => _handleReorder(context, order)
            : null,
      ),
    );
  }
}

// ── Completed ────────────────────────────────────────────────────────────────

class _CompletedOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _CompletedOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompletedOrderCubit>();
    return _PaginatedOrderList<OrderData>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noCompletedOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, order) => OrderCard(
        order: order,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.orderDetail,
            arguments: OrderDetailArgs(orderId: order.id?.toString() ?? ''),
          );
          // Already in this list — patch (return) rather than add.
          if (result is OrderData && context.mounted) {
            cubit.patchOrder(result);
          }
        },
        // PestRaksh: Book Again fills the Quick cart, and checkout shows the
        // cart of the active channel, so the button shows only in Quick mode
        // (once the zone is Quick only, always).
        onReorder: SettingsHiveBox.instance.channel == AppConstants.quick
            ? () => _handleReorder(context, order)
            : null,
      ),
    );
  }
}

// ── Ecommerce: Ongoing ──────────────────────────────────────────────────────

// PestRaksh: kept from the vendor but unused; My Bookings lists only Quick
// bookings.
// ignore: unused_element
class _OngoingEcommerceOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  // ignore: unused_element_parameter
  const _OngoingEcommerceOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OngoingEcommerceOrderCubit>();
    final completedCubit = context.read<CompletedEcommerceOrderCubit>();
    return _PaginatedOrderList<EcommerceOrderDataModel>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noOngoingOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, item) => EcommerceOrderCard(
        order: item,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.ecommerceOrderDetail,
            arguments: EcommerceOrderDetailArgs(
              orderItemId: item.id?.toString() ?? '',
              isOngoing: true,
            ),
          );
          if (result is EcommerceOrderDataModel && context.mounted) {
            cubit.removeOrder(result.id);
            completedCubit.addOrder(result);
          }
        },
        onReorder: _showEcommerceReorder
            ? () => _handleReorderEcommerceItem(context, item)
            : null,
      ),
    );
  }
}

// ── Ecommerce: Completed ────────────────────────────────────────────────────

// PestRaksh: kept from the vendor but unused; My Bookings lists only Quick
// bookings.
// ignore: unused_element
class _CompletedEcommerceOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  // ignore: unused_element_parameter
  const _CompletedEcommerceOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompletedEcommerceOrderCubit>();
    return _PaginatedOrderList<EcommerceOrderDataModel>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noCompletedOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, item) => EcommerceOrderCard(
        order: item,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.ecommerceOrderDetail,
            arguments: EcommerceOrderDetailArgs(
              orderItemId: item.id?.toString() ?? '',
            ),
          );
          // Already in this list — patch (return) rather than add.
          if (result is EcommerceOrderDataModel && context.mounted) {
            cubit.patchOrder(result);
          }
        },
        onReorder: _showEcommerceReorder
            ? () => _handleReorderEcommerceItem(context, item)
            : null,
      ),
    );
  }
}
