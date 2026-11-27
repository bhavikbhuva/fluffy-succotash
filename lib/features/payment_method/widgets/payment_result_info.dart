import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:flutter/widgets.dart';

/// PestRaksh: shows the server's note for a payment that is being confirmed,
/// or whose money went to the wallet, as information rather than an error.
/// Called by the gateway launchers after `addTransaction`, because checkout's
/// own listener shows only errors. The snackbar sits on the app's root
/// messenger, so it stays up when checkout moves on to the booking.
void showPaymentResultInfo(BuildContext context, PaymentState state) {
  final message = switch (state) {
    PaymentSuccess(:final infoMessage?) => infoMessage,
    PaymentInfo(:final message) => message,
    _ => null,
  };
  if (message == null || message.isEmpty) return;
  // Never throws: a launcher calls this inside a try whose catch deletes the
  // booking, and this booking has been paid.
  try {
    AppSnackBar.show(
      context: context,
      message: message,
      type: .info,
      duration: const Duration(seconds: 6),
    );
  } catch (_) {}
}
