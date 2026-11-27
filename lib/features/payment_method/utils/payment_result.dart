// PestRaksh: payment results that must not delete a booking. Same rules as
// the website (services-frontend 187932d, `usePaymentResult.ts`): money may
// already have been paid, and the server cancels an unpaid booking by itself
// after `unpaid_order_expiry_minutes`.
import 'package:customer/core/api/api_exception.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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

/// A Razorpay error that ends the booking: the customer closed the payment
/// window, or checkout could not start, so nothing was paid. After a failed
/// payment the booking stays: the customer can try again, and the server
/// cancels it if it stays unpaid (and sends "payment failed").
bool razorpayErrorDeletesBooking(int? code) =>
    code == Razorpay.PAYMENT_CANCELLED || code == Razorpay.INVALID_OPTIONS;

/// A gateway status saying the payment may still go through (UPI still
/// processing, for example). Such a booking must not be deleted.
bool isPendingPaymentStatus(String status) =>
    const {'pending', 'processing'}.contains(status.trim().toLowerCase());
