// PestRaksh: the two sheets of the "Visits & warranty" card: choosing a visit's
// time, and asking for a free re-visit (APP_PLAN Phase 4), as the website's
// BookingVisitsCard.tsx does them.
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/checkout/cubit/booking_slots_cubit.dart';
import 'package:customer/features/checkout/widgets/checkout_booking_slot_section.dart';
import 'package:customer/features/orders/models/booking_visits_model.dart';
import 'package:customer/features/orders/repositories/booking_visits_repository.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lets the customer pick a date and arrival window for [visit] of [line] and
/// books it. Resolves to true once the server has booked it.
Future<bool> showVisitTimeSheet(
  BuildContext context, {
  required BookingVisitsLine line,
  required BookingVisit visit,
  required BookingVisitsRepository repository,
}) async {
  final message = await showAppBottomSheet<String>(
    context,
    title: visit.isScheduled
        ? context.translate(
            LanguageLabelKeys.changeTime,
            fallback: 'Change time',
          )
        : context.translate(
            LanguageLabelKeys.chooseATime,
            fallback: 'Choose a time',
          ),
    builder: (_) =>
        _VisitTimeSheet(line: line, visit: visit, repository: repository),
  );
  if (!context.mounted) return message != null;
  return _done(context, message);
}

/// Asks for a free re-visit of [line], with an optional note. Resolves to true
/// once the server has the request.
Future<bool> showRevisitSheet(
  BuildContext context, {
  required BookingVisitsLine line,
  required BookingVisitsRepository repository,
}) async {
  final message = await showAppBottomSheet<String>(
    context,
    title: context.translate(
      LanguageLabelKeys.requestFreeRevisit,
      fallback: 'Request a free re-visit',
    ),
    builder: (_) => _RevisitSheet(line: line, repository: repository),
  );
  if (!context.mounted) return message != null;
  return _done(context, message);
}

/// PestRaksh: a sheet closes with the server's success message (possibly '')
/// and with null when dismissed. The message is shown on the page underneath
/// once the sheet is gone, because a snack bar opened from the sheet would sit
/// behind it.
bool _done(BuildContext context, String? message) {
  if (message == null) return false;
  if (message.isNotEmpty) {
    AppSnackBar.show(
      context: context,
      message: message,
      type: SnackBarType.success,
    );
  }
  return true;
}

/// The server's reason for refusing, or a general one.
String _errorText(BuildContext context, Object error) {
  final text = error is ApiException ? error.message.trim() : '';
  return text.isNotEmpty
      ? text
      : context.translate(
          LanguageLabelKeys.somethingWentWrong,
          fallback: 'Something went wrong. Please try again.',
        );
}

class _VisitTimeSheet extends StatefulWidget {
  const _VisitTimeSheet({
    required this.line,
    required this.visit,
    required this.repository,
  });

  final BookingVisitsLine line;
  final BookingVisit visit;
  final BookingVisitsRepository repository;

  @override
  State<_VisitTimeSheet> createState() => _VisitTimeSheetState();
}

class _VisitTimeSheetState extends State<_VisitTimeSheet> {
  // PestRaksh: the sheet owns a picker of its own, apart from checkout's, and
  // starts it on the visit's own date (booked, else due) when that date is
  // open. A due date already past is not in the list, so the first open date
  // is picked instead, as on the website. Loading starts here, so the section
  // doesn't start its own load without the date.
  late final BookingSlotsCubit _cubit = BookingSlotsCubit()
    ..load(widget.line.branchId, preferredDate: _startDate);

  bool _saving = false;
  String? _error;

  String? get _startDate {
    final v = widget.visit;
    if (v.bookingDate.isNotEmpty) return v.bookingDate;
    if (v.dueDate.isNotEmpty) return v.dueDate;
    return null;
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _confirm() async {
    final state = _cubit.state;
    final date = state.selectedDate;
    final slotId = state.selectedSlotId;
    if (_saving || !state.isComplete || date == null || slotId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.repository.schedule(
        visitId: widget.visit.id,
        date: date,
        slotId: slotId,
      );
      if (!mounted) return;
      AppNavigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      // PestRaksh: the window may have filled meanwhile: keep the sheet open
      // with the server's reason, and fetch the windows again.
      AppHaptics.error();
      setState(() {
        _saving = false;
        _error = _errorText(context, e);
      });
      _cubit.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.line.title;
    return PopScope(
      // PestRaksh: not closed mid-request, so a booked visit is never missed.
      canPop: !_saving,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            if (title.isNotEmpty) ...[
              AppText(
                title,
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h12,
            ],
            CheckoutBookingSlotSection(
              cubit: _cubit,
              branchId: widget.line.branchId,
              // PestRaksh: the sheet has its own title.
              showHeader: false,
            ),
            if (_error != null) ...[AppSpacing.h12, _ErrorText(_error!)],
            AppSpacing.h16,
            BlocBuilder<BookingSlotsCubit, BookingSlotsState>(
              bloc: _cubit,
              builder: (context, state) => AppButton(
                label: context.translate(
                  LanguageLabelKeys.confirmTime,
                  fallback: 'Confirm time',
                ),
                isLoading: _saving,
                onPressed: state.isComplete ? _confirm : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisitSheet extends StatefulWidget {
  const _RevisitSheet({required this.line, required this.repository});

  final BookingVisitsLine line;
  final BookingVisitsRepository repository;

  @override
  State<_RevisitSheet> createState() => _RevisitSheetState();
}

class _RevisitSheetState extends State<_RevisitSheet> {
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.repository.requestRevisit(
        orderItemId: widget.line.orderItemId,
        notes: _notes.text,
      );
      if (!mounted) return;
      AppNavigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() {
        _saving = false;
        _error = _errorText(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.line.title;
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            if (title.isNotEmpty) ...[
              AppText(
                title,
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h12,
            ],
            AppTextField(
              controller: _notes,
              hintText: context.translate(
                LanguageLabelKeys.revisitWhatHappened,
                fallback: 'Tell us what you noticed (optional)',
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              enabled: !_saving,
            ),
            if (_error != null) ...[AppSpacing.h12, _ErrorText(_error!)],
            AppSpacing.h16,
            Row(
              spacing: ThemeConstants.spaceM,
              children: [
                Expanded(
                  child: AppButton(
                    label: context.translate(
                      LanguageLabelKeys.cancel,
                      fallback: 'Cancel',
                    ),
                    variant: AppButtonVariant.outline,
                    onPressed: _saving ? null : () => AppNavigator.pop(context),
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: context.translate(
                      LanguageLabelKeys.sendRequest,
                      fallback: 'Send request',
                    ),
                    isLoading: _saving,
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The server's reason for refusing, shown inside the sheet.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        Icon(
          Icons.error_outline,
          size: ThemeConstants.iconS,
          color: context.cs.error,
        ),
        AppSpacing.w8,
        Expanded(
          child: AppText(
            text,
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
