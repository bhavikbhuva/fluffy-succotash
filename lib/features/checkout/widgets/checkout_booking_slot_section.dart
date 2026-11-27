// PestRaksh: "Service Schedule & Time Slot" on checkout: a strip of dates and
// the arrival windows of the chosen date, as on the website
// (BookingDatePicker.tsx). Required: place_order refuses a booking without it.
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/cubit/booking_slots_cubit.dart';
import 'package:customer/features/checkout/models/booking_slots_model.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const Color _kOkGreen = Color(0xFF15803D);
const Color _kFewLeftAmber = Color(0xFFB45309);

/// "Thursday, 27 Nov" for a calendar day.
String bookingDayLong(DateTime day) => DateFormat('EEEE, d MMM').format(day);

class CheckoutBookingSlotSection extends StatefulWidget {
  const CheckoutBookingSlotSection({
    super.key,
    required this.cubit,
    required this.branchId,
    this.showHeader = true,
  });

  final BookingSlotsCubit cubit;

  /// PestRaksh: the "Service Schedule & Time Slot" heading; a sheet with its
  /// own title (a follow-up visit's time) leaves it out.
  final bool showHeader;

  /// The branch whose schedule applies (the cart's `pickup.branch_id`, as the
  /// website asks); 0 is the shared schedule.
  final int branchId;

  @override
  State<CheckoutBookingSlotSection> createState() =>
      _CheckoutBookingSlotSectionState();
}

class _CheckoutBookingSlotSectionState
    extends State<CheckoutBookingSlotSection> {
  @override
  void initState() {
    super.initState();
    if (widget.cubit.state.status == BookingSlotsStatus.initial) {
      widget.cubit.load(widget.branchId);
    }
  }

  @override
  void didUpdateWidget(covariant CheckoutBookingSlotSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      widget.cubit.load(widget.branchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingSlotsCubit, BookingSlotsState>(
      bloc: widget.cubit,
      builder: (context, state) {
        return CheckoutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showHeader) ...[_Header(), AppSpacing.h12],
              ..._body(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, BookingSlotsState state) {
    if (state.dates.isEmpty) {
      if (state.status == BookingSlotsStatus.loading ||
          state.status == BookingSlotsStatus.initial) {
        return const [
          SizedBox(
            height: 88,
            child: Center(
              child: SizedBox(
                width: ThemeConstants.loaderSize,
                height: ThemeConstants.loaderSize,
                child: CircularProgressIndicator(
                  strokeWidth: ThemeConstants.loaderStroke,
                ),
              ),
            ),
          ),
        ];
      }
      if (state.status == BookingSlotsStatus.error) {
        return [
          _Notice(
            title: state.message ?? '',
            action: TextButton(
              onPressed: widget.cubit.reload,
              child: AppText(
                context.translate(LanguageLabelKeys.retry, fallback: 'Retry'),
              ),
            ),
          ),
        ];
      }
      return [
        _Notice(
          title: context.translate(
            LanguageLabelKeys.noSlotsConfigured,
            fallback: 'No Service Appointments Available',
          ),
          subtitle: context.translate(
            LanguageLabelKeys.appointmentsClosedLocation,
            fallback:
                'Bookings are not open for this location right now. Please contact us.',
          ),
        ),
      ];
    }

    final day = state.selectedDay;
    final dayDate = day?.day;
    final slot = state.selectedSlot;
    return [
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.dates.length,
          separatorBuilder: (_, _) => AppSpacing.w8,
          itemBuilder: (context, i) {
            final d = state.dates[i];
            return _DateChip(
              day: d,
              selected: d.date == state.selectedDate,
              onTap: () => widget.cubit.selectDate(d),
            );
          },
        ),
      ),
      if (day != null) ...[
        AppSpacing.h16,
        AppText(
          '${context.translate(LanguageLabelKeys.availableTimeSlots, fallback: 'Available Arrival Windows for')} '
          '${dayDate != null ? bookingDayLong(dayDate) : day.date}',
          style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        AppSpacing.h8,
        if (day.slots.isEmpty)
          _Notice(
            title: context.translate(
              LanguageLabelKeys.noSlotsAvailableForDate,
              fallback:
                  'No available service slots for this date. Please select another date above.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = ThemeConstants.spaceS;
              final width = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in day.slots)
                    SizedBox(
                      width: width,
                      child: _SlotTile(
                        slot: s,
                        selected: s.id == state.selectedSlotId,
                        onTap: () => widget.cubit.selectSlot(s),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
      if (dayDate != null && slot != null) ...[
        AppSpacing.h12,
        _ArrivalBanner(
          text: context
              .translate(
                LanguageLabelKeys.technicianArrivesOn,
                fallback:
                    'Your technician will arrive on {date} between {window}.',
              )
              .replaceAll('{date}', bookingDayLong(dayDate))
              .replaceAll('{window}', slot.displayLabel),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: ThemeConstants.iconM,
          color: context.cs.primary,
        ),
        AppSpacing.w8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: ThemeConstants.spaceS,
                runSpacing: ThemeConstants.spaceXS,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppText(
                    context.translate(
                      LanguageLabelKeys.serviceSchedule,
                      fallback: 'Service Schedule & Time Slot',
                    ),
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingS,
                      vertical: 2,
                    ),
                    decoration: AppDecorations.box(
                      color: context.cs.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r10,
                    ),
                    child: AppText(
                      context.translate(
                        LanguageLabelKeys.required,
                        fallback: 'Required',
                      ),
                      style: context.tt.labelSmall?.copyWith(
                        color: context.cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.h4,
              AppText(
                context.translate(
                  LanguageLabelKeys.pickPreferredSlot,
                  fallback:
                      'Choose your preferred visit date and technician arrival window',
                ),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final BookingSlotDate day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = day.day;
    final available = day.isAvailable;
    final fg = selected ? context.cs.onPrimary : context.cs.onSurface;
    final fgSoft = selected
        ? context.cs.onPrimary.withValues(alpha: 0.85)
        : context.cs.onSurfaceVariant;

    String? status;
    if (!available) {
      status = day.isBlackout
          ? context.translate(
              LanguageLabelKeys.bookingDayHoliday,
              fallback: 'Holiday',
            )
          : day.isDayOff
          ? context.translate(
              LanguageLabelKeys.bookingDayClosed,
              fallback: 'Closed',
            )
          : context.translate(
              LanguageLabelKeys.bookingDayFull,
              fallback: 'Full',
            );
    }

    return Opacity(
      opacity: available ? 1 : 0.45,
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: available ? onTap : null,
        child: Container(
          width: 66,
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: ThemeConstants.paddingS,
          ),
          decoration: AppDecorations.box(
            color: selected ? context.cs.primary : context.cs.surface,
            borderRadius: AppRadius.r12,
            border: Border.all(
              color: selected
                  ? context.cs.primary
                  : context.cs.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (day.isToday)
                AppText(
                  context
                      .translate(LanguageLabelKeys.today, fallback: 'Today')
                      .toUpperCase(),
                  maxLines: 1,
                  style: context.tt.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: selected ? context.cs.onPrimary : context.cs.primary,
                  ),
                ),
              AppText(
                date != null ? DateFormat('EEE').format(date) : '',
                maxLines: 1,
                style: context.tt.labelSmall?.copyWith(color: fgSoft),
              ),
              AppText(
                date != null ? '${date.day}' : day.date,
                maxLines: 1,
                style: context.tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              AppText(
                status ?? (date != null ? DateFormat('MMM').format(date) : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(
                  color: status != null ? context.cs.error : fgSoft,
                  fontWeight: status != null ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final BookingSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = slot.isAvailable;
    final String hint;
    final Color hintColor;
    if (!available) {
      hint = slot.isPassedToday
          ? context.translate(
              LanguageLabelKeys.windowPassed,
              fallback: 'Window passed',
            )
          : context.translate(
              LanguageLabelKeys.fullyBooked,
              fallback: 'Fully booked',
            );
      hintColor = context.cs.error;
    } else if (slot.remainingCapacity <= 2) {
      hint = slot.remainingCapacity > 1
          ? context
                .translate(
                  LanguageLabelKeys.onlySpotsLeft,
                  fallback: 'Only {count} spots left',
                )
                .replaceAll('{count}', '${slot.remainingCapacity}')
          : context.translate(
              LanguageLabelKeys.onlyOneSpotLeft,
              fallback: 'Only 1 spot left',
            );
      hintColor = _kFewLeftAmber;
    } else {
      hint = context
          .translate(
            LanguageLabelKeys.spotsAvailable,
            fallback: '{count} spots available',
          )
          .replaceAll('{count}', '${slot.remainingCapacity}');
      hintColor = _kOkGreen;
    }

    return Opacity(
      opacity: available ? 1 : 0.5,
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: available ? onTap : null,
        child: Container(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: AppDecorations.box(
            color: selected
                ? _kOkGreen.withValues(alpha: 0.08)
                : context.cs.surface,
            borderRadius: AppRadius.r12,
            border: Border.all(
              color: selected
                  ? _kOkGreen
                  : context.cs.outline.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppText(
                      slot.displayLabel,
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: ThemeConstants.iconXS,
                      color: _kOkGreen,
                    ),
                ],
              ),
              AppSpacing.h4,
              AppText(
                hint,
                maxLines: 2,
                style: context.tt.labelSmall?.copyWith(
                  color: hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: _kFewLeftAmber.withValues(alpha: 0.06),
        borderRadius: AppRadius.r12,
        border: Border.all(color: _kFewLeftAmber.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            size: ThemeConstants.iconM,
            color: _kFewLeftAmber,
          ),
          AppSpacing.h4,
          AppText(
            title,
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            AppSpacing.h4,
            AppText(
              subtitle!,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
          ?action,
        ],
      ),
    );
  }
}

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        color: _kOkGreen.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: _kOkGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: ThemeConstants.iconS,
            color: _kOkGreen,
          ),
          AppSpacing.w8,
          Expanded(
            child: AppText(
              text,
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
