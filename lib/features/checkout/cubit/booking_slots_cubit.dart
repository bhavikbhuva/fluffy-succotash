// PestRaksh: the booking date and arrival window chosen at checkout. The backend
// requires both at place_order (`booking_date`, `booking_slot_id`) and checks
// them again there, so this only mirrors its list.
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/checkout/models/booking_slots_model.dart';
import 'package:customer/features/checkout/repositories/booking_slots_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum BookingSlotsStatus { initial, loading, loaded, error }

class BookingSlotsState {
  const BookingSlotsState({
    this.status = BookingSlotsStatus.initial,
    this.dates = const [],
    this.selectedDate,
    this.selectedSlotId,
    this.message,
  });

  final BookingSlotsStatus status;
  final List<BookingSlotDate> dates;

  /// "YYYY-MM-DD" of the chosen date.
  final String? selectedDate;
  final int? selectedSlotId;

  /// Why the list could not be loaded.
  final String? message;

  BookingSlotDate? get selectedDay {
    for (final d in dates) {
      if (d.date == selectedDate) return d;
    }
    return null;
  }

  BookingSlot? get selectedSlot => selectedDay?.slotById(selectedSlotId);

  /// A date and a window that can still be booked are chosen.
  bool get isComplete =>
      selectedDay?.isAvailable == true && selectedSlot?.isAvailable == true;
}

class BookingSlotsCubit extends Cubit<BookingSlotsState> {
  BookingSlotsCubit({BookingSlotsRepository? repository})
    : _repository = repository ?? BookingSlotsRepository(),
      super(const BookingSlotsState());

  final BookingSlotsRepository _repository;
  int? _branchId;

  /// Loads the list for [branchId]. The customer's choice is kept while it can
  /// still be booked; otherwise the first open date is picked, as on the
  /// website.
  Future<void> load(int branchId) async {
    _branchId = branchId;
    emit(
      BookingSlotsState(
        status: BookingSlotsStatus.loading,
        dates: state.dates,
        selectedDate: state.selectedDate,
        selectedSlotId: state.selectedSlotId,
      ),
    );
    try {
      final dates = await _repository.fetch(branchId: branchId);
      if (isClosed || _branchId != branchId) return;

      BookingSlotDate? keptDay;
      for (final d in dates) {
        if (d.date == state.selectedDate && d.isAvailable) keptDay = d;
      }
      BookingSlotDate? day = keptDay;
      if (day == null) {
        for (final d in dates) {
          if (d.isAvailable) {
            day = d;
            break;
          }
        }
      }
      final keptSlot = keptDay?.slotById(state.selectedSlotId);

      emit(
        BookingSlotsState(
          status: BookingSlotsStatus.loaded,
          dates: dates,
          selectedDate: day?.date,
          selectedSlotId: keptSlot != null && keptSlot.isAvailable
              ? keptSlot.id
              : null,
        ),
      );
    } catch (_) {
      if (isClosed || _branchId != branchId) return;
      emit(
        BookingSlotsState(
          status: BookingSlotsStatus.error,
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.unableToLoadBookingSlots,
            fallback: 'Could not load the arrival windows. Please try again.',
          ),
        ),
      );
    }
  }

  /// Loads the list again for the same branch, e.g. after the backend refused
  /// a window that was taken meanwhile.
  Future<void> reload() async {
    final branchId = _branchId;
    if (branchId != null) await load(branchId);
  }

  void selectDate(BookingSlotDate day) {
    if (!day.isAvailable || day.date == state.selectedDate) return;
    emit(
      BookingSlotsState(
        status: state.status,
        dates: state.dates,
        selectedDate: day.date,
      ),
    );
  }

  void selectSlot(BookingSlot slot) {
    if (!slot.isAvailable) return;
    emit(
      BookingSlotsState(
        status: state.status,
        dates: state.dates,
        selectedDate: state.selectedDate,
        selectedSlotId: slot.id,
      ),
    );
  }
}
