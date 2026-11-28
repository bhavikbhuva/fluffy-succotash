// PestRaksh: payment results that must not delete a booking. Same rules as
// the website (services-frontend 187932d, `usePaymentResult.ts`): money may
// already have been paid, and the server cancels an unpaid booking by itself
// after `unpaid_order_expiry_minutes`.
import 'package:customer/core/api/api_exception.dart';

/// What the server's answer to a payment means, beyond success or failure.
enum PaymentResult {
  /// Paid, and the server is still confirming it. The booking stays.
  processing,

  /// The money went to the customer's wallet (the booking was cancelled
  /// before the payment reached the server).
  toWallet,

  /// Anything else: a success or a real failure, handled as before.
  other,
}

/// Reads the result from the server's `status_code`, else from its `message`
/// (where older servers put the code), as the website does.
PaymentResult paymentResultOf({String? statusCode, String? message}) {
  final code = (statusCode?.trim().isNotEmpty ?? false)
      ? statusCode!
      : (message ?? '');
  return switch (code.trim().toUpperCase()) {
    'PAYMENT_PROCESSING' => .processing,
    'PAYMENT_TO_WALLET' => .toWallet,
    _ => .other,
  };
}

/// [paymentResultOf] for a refused API call (`status` other than 1).
PaymentResult paymentResultOfError(ApiException e) => paymentResultOf(
  statusCode: e.messageStatusCode ?? e.responseData?['status_code']?.toString(),
  message: e.responseData?['message']?.toString() ?? e.message,
);

/// A Razorpay error that ends the booking: every one of them. In the mobile
/// SDK the error arrives only after the payment window has closed (retries
/// happen inside the window), so the app has no way left to pay a kept
/// booking: pressing "Place booking" again makes a second one, while the
/// first holds its time window until the server's unpaid-booking expiry.
/// The website does the same when its window closes (services-frontend
/// 187932d). A payment that still goes through for the deleted booking is
/// moved to the wallet by the server's webhook, which the app shows as
/// information. Paid results (`PAYMENT_PROCESSING`, `PAYMENT_TO_WALLET`)
/// come only after a success and never delete.
// PestRaksh: was only PAYMENT_CANCELLED and INVALID_OPTIONS (Phase 8), which
// left bookings the app could not pay after any other error.
bool razorpayErrorDeletesBooking(int? code) => true;

/// A gateway status saying the payment may still go through (UPI still
/// processing, for example). Such a booking must not be deleted.
bool isPendingPaymentStatus(String status) =>
    const {'pending', 'processing'}.contains(status.trim().toLowerCase());
