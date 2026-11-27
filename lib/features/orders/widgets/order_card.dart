import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/utils/booking_text.dart';
import 'package:customer/features/orders/utils/order_payment_utils.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OrderCard extends StatelessWidget {
  final OrderData order;
  final VoidCallback onTap;
  final VoidCallback? onReorder;
  final VoidCallback? onTrack;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onReorder,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = order.activeStatus == OrderStatus.paymentPending;
    final statusColor = isActive
        ? context.cs.errorContainer
        : context.cs.onSecondaryContainer;
    final dividerColor = context.cs.outlineVariant;
    final items = order.items ?? [];
    final displayItems = items.take(2).toList();
    final extraCount = items.length - displayItems.length;
    final hasDate = order.date.hasValue;
    // PestRaksh: a booking card says when the visit is and who comes, as the
    // website's booking cards do. Each line shows only when it has a value.
    final appointment = bookingAppointmentText(
      order.bookingDate,
      order.bookingTimeLabel,
    );
    // PestRaksh: only while a technician is on the job or has done it.
    final technician = bookingTechnicianName(order);
    // Track button: quick orders only (ecommerce has no live rider to
    // track) and only while the order is still active — hidden once
    // delivered/cancelled/returned. Cancel now lives on the order detail
    // screen. Also hidden for pickup orders — no delivery boy/live GPS ever
    // exists for one (its status flow never reaches out-for-delivery), so
    // there's nothing on the tracking map worth showing.
    final isQuickOrder = order.channel == AppConstants.quick;
    final isPickupOrder =
        DeliveryType.fromApiValue(order.deliveryType) == DeliveryType.pickup;
    final isActiveOrder =
        order.activeStatus != OrderStatus.delivered &&
        order.activeStatus != OrderStatus.cancelled &&
        order.activeStatus != OrderStatus.returned;
    final showTrackButton =
        isQuickOrder && !isPickupOrder && isActiveOrder && onTrack != null;
    final paymentInfo = resolveOrderPaymentInfo(
      context: context,
      walletUsed: order.paidWallet,
      finalTotal: order.finalTotal,
      rawPaymentMethod: order.paymentMethod,
      isDelivered: order.activeStatus == OrderStatus.delivered,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(
          bottom: ThemeConstants.paddingM,
        ),
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        decoration: AppDecorations.shadowedCard(
          color: Theme.of(context).cardColor,
          shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // ── Header: order ID + status ──
            Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .start,
              children: [
                Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(
                      order.orderNumber ?? '',
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (hasDate)
                      AppText(
                        AppDateFormatter.formatDateTime(order.date!),
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                _Chip(
                  label:
                      order.orderStatusName ??
                      (isActive
                          ? context.translate(LanguageLabelKeys.ongoing)
                          : context.translate(LanguageLabelKeys.completed)),
                  color: statusColor,
                ),
              ],
            ),

            // ── Divider ──
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingS,
              ),
              child: Divider(height: 1, color: dividerColor),
            ),

            // ── Items ──
            if (displayItems.isNotEmpty) ...[
              AppSpacing.h10,
              ...displayItems.map(
                (item) => _ItemRow(item: item, currency: order.currency),
              ),
              if (extraCount > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: ThemeConstants.paddingXS,
                  ),
                  child: AppText(
                    '+$extraCount ${context.translate(extraCount > 1 ? LanguageLabelKeys.moreItems : LanguageLabelKeys.moreItem)}',
                    style: context.tt.bodySmall?.copyWith(
                      color: context.cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],

            // PestRaksh: the visit's date and time window, then the
            // technician, under the services.
            if (appointment.isNotEmpty || technician.isNotEmpty) ...[
              AppSpacing.h4,
              if (appointment.isNotEmpty)
                _InfoLine(
                  icon: Icons.calendar_today_outlined,
                  label: '${context.translate(LanguageLabelKeys.appointment)}:',
                  value: appointment,
                ),
              if (technician.isNotEmpty)
                _InfoLine(
                  icon: Icons.person_outline,
                  label: '${context.translate(LanguageLabelKeys.technician)}:',
                  value: technician,
                ),
            ],

            // ── Divider ──
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingS,
              ),
              child: Divider(height: 1, color: dividerColor),
            ),

            // ── Footer: total ──
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                AppText(
                  paymentInfo.totalRowIsWalletHighlighted
                      ? paymentInfo.combinedTotalRowLabel
                      : context.translate(LanguageLabelKeys.totalOrderPrice),
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppText(
                  '${order.currency}${paymentInfo.combinedTotalRowAmount.formatPrice()}',
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.cs.onSurface,
                  ),
                ),
              ],
            ),

            // ── Action buttons ──
            if (onReorder != null || showTrackButton) ...[
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: ThemeConstants.paddingS,
                ),
                child: Divider(height: 1, color: dividerColor),
              ),
              Row(
                mainAxisAlignment: .end,
                spacing: ThemeConstants.spaceM,
                children: [
                  if (showTrackButton)
                    AppButton(
                      label: context.translate(LanguageLabelKeys.track),
                      onPressed: onTrack,
                      variant: AppButtonVariant.outline,
                      fullWidth: false,
                      height: 32,
                      fontSize: 13,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingL,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      prefixIcon: AppSvgIcon(
                        AssetsConstants.addressIcon,
                        size: ThemeConstants.iconS,
                        color: context.cs.primary,
                        bakeTint: true,
                      ),
                    ),
                  if (onReorder != null)
                    AppButton(
                      label: context.translate(LanguageLabelKeys.reorder),
                      onPressed: onReorder,
                      fullWidth: false,
                      height: 32,
                      fontSize: 13,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingL,
                        vertical: ThemeConstants.paddingXS,
                      ),
                      prefixIcon: AppSvgIcon(
                        AssetsConstants.refreshIcon,
                        size: ThemeConstants.iconS,
                        color: context.cs.onPrimary,
                        bakeTint: true,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItems item;
  final String? currency;
  const _ItemRow({required this.item, this.currency});

  @override
  Widget build(BuildContext context) {
    // PestRaksh: the service is the title and the package it was booked as
    // goes under it, as on the website. "1 x" is dropped: a booking is one
    // visit, so only a real count (2 or more) is shown.
    final name = bookingLineTitle(item);
    final package = bookingLinePackage(item);
    final variant =
        VariantAttributesFormatter.format(item.variantAttributes) ?? "";
    final qty = item.quantity ?? 0;
    final price = item.price ?? 0;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingXS,
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceS,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text.rich(
                  ProductTypeIcon.nameSpan(
                    productType: item.productType,
                    name: qty > 1 ? '$qty x $name' : name,
                    size: ThemeConstants.iconXXS,
                  ),
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  // PestRaksh: long service names get a second line.
                  maxLines: 2,
                  overflow: .ellipsis,
                ),
                if (package.isNotEmpty)
                  AppText(
                    package,
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                if (variant.isNotEmpty)
                  AppText(
                    variant,
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                // Add-on module: chosen options in one receipt-style
                // line ("Cheese burst +₹30, Paneer, 2 × Olives").
                if (item.addons?.isNotEmpty ?? false)
                  AppText(
                    formatCartAddons(item.addons!, currency: currency ?? ''),
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
              ],
            ),
          ),
          AppText(
            '$currency$price',
            style: context.tt.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// PestRaksh: one small grey line with an icon, a label and a value, for the
// appointment and the technician.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.tt.labelSmall?.copyWith(
      color: context.cs.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingXS),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceXS,
        children: [
          Icon(icon, size: ThemeConstants.iconXXS, color: style?.color),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: style,
              maxLines: 2,
              overflow: .ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppText(
      label,
      style: context.tt.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
