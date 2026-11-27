// PestRaksh: the "Visits & warranty" card on the booking page (APP_PLAN
// Phase 4), as the website's BookingVisitsCard.tsx: per service, its visits
// with their state and a button to choose or change a visit's time, then the
// warranty and a button to ask for a free re-visit. Shows nothing when the
// booking has no plan, warranty or follow-up visits.
import 'dart:math';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/orders/cubit/booking_visits_cubit.dart';
import 'package:customer/features/orders/models/booking_visits_model.dart';
import 'package:customer/features/orders/utils/booking_text.dart';
import 'package:customer/features/orders/widgets/booking_visit_sheets.dart';
import 'package:customer/features/orders/widgets/order_detail_shared_widgets.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BookingVisitsCard extends StatelessWidget {
  const BookingVisitsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingVisitsCubit, List<BookingVisitsLine>>(
      builder: (context, lines) {
        if (lines.isEmpty) return AppSpacing.shrink;
        return Padding(
          // The page puts a 12 gap before each card; this one adds its own
          // so that an empty card leaves no gap.
          padding: const EdgeInsetsDirectional.only(top: ThemeConstants.spaceM),
          child: OrderDetailCard(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                OrderDetailSectionTitle(
                  title: context.translate(LanguageLabelKeys.visitsAndWarranty),
                ),
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) ...[
                    AppSpacing.h12,
                    Divider(height: 1, color: context.cs.outlineVariant),
                  ],
                  AppSpacing.h12,
                  _LineSection(line: lines[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One booked service: its title, its visits and its warranty.
class _LineSection extends StatelessWidget {
  final BookingVisitsLine line;
  const _LineSection({required this.line});

  Future<void> _requestRevisit(BuildContext context) async {
    final cubit = context.read<BookingVisitsCubit>();
    final ok = await showRevisitSheet(
      context,
      line: line,
      repository: cubit.repository,
    );
    if (ok) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = line.summary;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: ThemeConstants.spaceS,
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            AppText(
              line.title,
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: .ellipsis,
            ),
            if (line.package.isNotEmpty)
              AppText(
                line.package,
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
          ],
        ),
        for (final visit in line.visits) _VisitRow(line: line, visit: visit),
        if (summary.warrantyDays > 0) _WarrantyBox(summary: summary),
        if (line.canRequestRevisit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: context.translate(LanguageLabelKeys.requestFreeRevisit),
              onPressed: () => _requestRevisit(context),
              variant: AppButtonVariant.outline,
              fullWidth: false,
              height: 36,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

/// "Visit 2 of 3" or "Warranty re-visit", its state, and a time button.
class _VisitRow extends StatelessWidget {
  final BookingVisitsLine line;
  final BookingVisit visit;
  const _VisitRow({required this.line, required this.visit});

  Future<void> _chooseTime(BuildContext context) async {
    final cubit = context.read<BookingVisitsCubit>();
    final ok = await showVisitTimeSheet(
      context,
      line: line,
      visit: visit,
      repository: cubit.repository,
    );
    if (ok) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final title = visit.isRevisit
        ? context.translate(LanguageLabelKeys.warrantyRevisit)
        : context
              .translate(LanguageLabelKeys.visitNOfM)
              .replaceAll('{n}', '${visit.visitNo}')
              .replaceAll(
                '{m}',
                '${max(line.summary.planVisits, visit.visitNo)}',
              );
    final done = visit.isDone;
    final booked = visit.isScheduled;
    // Done and booked: green; due: amber. The theme keeps success in
    // onSecondaryContainer and warning in errorContainer (see app_theme.dart).
    final String state;
    Color? stateColor;
    if (done) {
      final date = bookingVisitDate(visit.bookingDate);
      state =
          '${context.translate(LanguageLabelKeys.visitDone)}'
          '${date.isNotEmpty ? ' · $date' : ''}';
      stateColor = context.cs.onSecondaryContainer;
    } else if (visit.isSkipped) {
      state = context.translate(LanguageLabelKeys.visitSkipped);
    } else if (booked) {
      state =
          '${context.translate(LanguageLabelKeys.visitBookedFor)} '
          '${bookingAppointmentText(visit.bookingDate, visit.bookingTimeLabel)}'
          '${visit.technicianName.isNotEmpty ? ' · ${context.translate(LanguageLabelKeys.technician)}: ${visit.technicianName}' : ''}';
      stateColor = context.cs.onSecondaryContainer;
    } else {
      state =
          '${context.translate(LanguageLabelKeys.visitDueAround)} '
          '${bookingVisitDate(visit.dueDate)}';
      stateColor = context.cs.errorContainer;
    }

    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.outlinedCard(
        borderColor: context.cs.outlineVariant,
        borderRadius: 12,
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceXXS,
        children: [
          AppText(
            title,
            style: context.tt.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppText(
            state,
            style: context.tt.bodySmall?.copyWith(
              fontWeight: stateColor != null ? FontWeight.w600 : null,
              color: stateColor ?? context.cs.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: .ellipsis,
          ),
          // Booked for today: already on the technician's round.
          if (booked && !visit.canSchedule)
            AppText(
              context.translate(LanguageLabelKeys.visitTodayCallUs),
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          if (visit.canSchedule) ...[
            AppSpacing.h4,
            AppButton(
              label: context.translate(
                booked
                    ? LanguageLabelKeys.changeTime
                    : LanguageLabelKeys.chooseATime,
              ),
              onPressed: () => _chooseTime(context),
              variant: booked
                  ? AppButtonVariant.outline
                  : AppButtonVariant.primary,
              prefixIcon: const Icon(
                Icons.edit_calendar_outlined,
                size: ThemeConstants.iconXS,
              ),
              fullWidth: false,
              height: 36,
              fontSize: 13,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Warranty until 27 Nov 2027 · 2 free re-visits left", "Warranty ended
/// on ...", or "Warranty starts after the last visit."
class _WarrantyBox extends StatelessWidget {
  final BookingVisitsSummary summary;
  const _WarrantyBox({required this.summary});

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;
    final String text;
    if (summary.warrantyUntil.isEmpty) {
      text = context.translate(LanguageLabelKeys.warrantyStartsAfterLastVisit);
    } else {
      final label = context.translate(
        summary.inWarranty
            ? LanguageLabelKeys.warrantyUntil
            : LanguageLabelKeys.warrantyEndedOn,
      );
      final left = summary.inWarranty && summary.freeRevisits > 0
          ? ' · ${summary.revisitsLeft} ${context.translate(LanguageLabelKeys.freeRevisitsLeft)}'
          : '';
      text = '$label ${bookingVisitDate(summary.warrantyUntil)}$left';
    }
    return Container(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceS,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: ThemeConstants.iconXS,
            color: primary,
          ),
          Expanded(
            child: AppText(
              text,
              style: context.tt.bodySmall?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
