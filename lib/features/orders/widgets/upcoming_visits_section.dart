// PestRaksh: follow-up visits (visit 2 of a yearly plan, a warranty re-visit)
// at the top of My Bookings → Upcoming. The booking itself moves to Past once
// its first visit is done, so without this a customer with visits still to
// come saw no upcoming bookings. As the website's UpcomingVisitCard.tsx, but
// with no button: choosing a visit's time comes in a later phase, so a card
// opens its booking.
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/orders/cubit/upcoming_visits_cubit.dart';
import 'package:customer/features/orders/models/upcoming_visit_model.dart';
import 'package:customer/features/orders/utils/booking_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpcomingVisitsSection extends StatelessWidget {
  const UpcomingVisitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpcomingVisitsCubit, List<UpcomingVisit>>(
      builder: (context, visits) {
        // No visits: no header and no space.
        if (visits.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: ThemeConstants.paddingS,
              ),
              child: AppText(
                context.translate(LanguageLabelKeys.followUpVisits),
                style: context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final visit in visits) _UpcomingVisitCard(visit: visit),
          ],
        );
      },
    );
  }
}

class _UpcomingVisitCard extends StatelessWidget {
  final UpcomingVisit visit;

  const _UpcomingVisitCard({required this.visit});

  Future<void> _openBooking(BuildContext context) async {
    final cubit = context.read<UpcomingVisitsCubit>();
    await AppNavigator.pushNamed(
      context,
      RouteNames.orderDetail,
      arguments: OrderDetailArgs(
        orderId: visit.orderId.toString(),
        isOngoing: true,
      ),
    );
    // The booking's page may have changed its visits.
    cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final label = visit.isRevisit
        ? context.translate(LanguageLabelKeys.warrantyRevisit)
        : context
              .translate(LanguageLabelKeys.visitNOfM)
              .replaceAll('{n}', '${visit.visitNo}')
              .replaceAll('{m}', '${visit.visitsShownTotal}');
    // Booked: green. Not booked yet: amber, or red once the due date passed.
    // The theme keeps success in onSecondaryContainer and warning in
    // errorContainer (see app_theme.dart).
    final status = visit.isScheduled
        ? '${context.translate(LanguageLabelKeys.visitBookedFor)} '
              '${bookingAppointmentText(visit.bookingDate, visit.bookingTimeLabel)}'
        : '${context.translate(LanguageLabelKeys.visitDueAround)} '
              '${bookingVisitDate(visit.dueDate)}';
    final statusColor = visit.isScheduled
        ? context.cs.onSecondaryContainer
        : visit.overdue
        ? context.cs.error
        : context.cs.errorContainer;
    final primary = context.cs.primary;

    return GestureDetector(
      onTap: () => _openBooking(context),
      child: Container(
        width: double.infinity,
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
          spacing: ThemeConstants.spaceXXS,
          children: [
            // ── Label: "Visit 2 of 3" or "Warranty re-visit" ──
            Container(
              margin: const EdgeInsetsDirectional.only(
                bottom: ThemeConstants.spaceXS,
              ),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingS,
                vertical: ThemeConstants.spaceXXS,
              ),
              decoration: AppDecorations.box(
                color: primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.pill,
              ),
              child: Row(
                mainAxisSize: .min,
                spacing: ThemeConstants.spaceXS,
                children: [
                  Icon(
                    visit.isScheduled
                        ? Icons.event_available_outlined
                        : Icons.schedule_outlined,
                    size: ThemeConstants.iconXXS,
                    color: primary,
                  ),
                  AppText(
                    label,
                    style: context.tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            AppText(
              visit.title,
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: .ellipsis,
            ),
            if (visit.package.isNotEmpty)
              AppText(
                visit.package,
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            AppText(
              status,
              style: context.tt.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
              maxLines: 2,
              overflow: .ellipsis,
            ),
            AppText(
              '${context.translate(LanguageLabelKeys.booking)} ${visit.orderNumber}',
              style: context.tt.labelSmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
