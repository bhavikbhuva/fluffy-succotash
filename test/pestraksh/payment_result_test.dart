// PestRaksh: payment results that must not delete a booking, as on the
// website (services-frontend 187932d, `usePaymentResult.ts`).
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/payment_method/utils/payment_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

void main() {
  group('paymentResultOf', () {
    test('reads status_code', () {
      expect(
        paymentResultOf(
          statusCode: 'PAYMENT_PROCESSING',
          message: 'Your payment is being confirmed.',
        ),
        PaymentResult.processing,
      );
      expect(
        paymentResultOf(statusCode: 'PAYMENT_TO_WALLET', message: 'Added.'),
        PaymentResult.toWallet,
      );
    });

    test('falls back to the message when there is no status_code', () {
      expect(
        paymentResultOf(statusCode: '', message: ' payment_processing '),
        PaymentResult.processing,
      );
      expect(
        paymentResultOf(message: 'PAYMENT_TO_WALLET'),
        PaymentResult.toWallet,
      );
    });

    test('anything else is not one of them', () {
      expect(paymentResultOf(), PaymentResult.other);
      expect(
        paymentResultOf(message: 'Transaction Failed, Please try again!'),
        PaymentResult.other,
      );
      expect(
        paymentResultOf(statusCode: 'CART_BRANCH_CHANGED'),
        PaymentResult.other,
      );
    });

    test('status_code wins over the message', () {
      expect(
        paymentResultOf(statusCode: 'OTHER', message: 'PAYMENT_PROCESSING'),
        PaymentResult.other,
      );
    });
  });

  group('paymentResultOfError', () {
    test('a refused call carrying the code', () {
      const e = ApiException(
        message: 'Your payment is being confirmed.',
        statusCode: 200,
        messageStatusCode: 'PAYMENT_PROCESSING',
        responseData: {
          'status': 0,
          'message': 'Your payment is being confirmed.',
          'status_code': 'PAYMENT_PROCESSING',
        },
      );
      expect(paymentResultOfError(e), PaymentResult.processing);
    });

    test('the code only in the body', () {
      const e = ApiException(
        message: 'Added to your wallet.',
        responseData: {'status': 0, 'status_code': 'PAYMENT_TO_WALLET'},
      );
      expect(paymentResultOfError(e), PaymentResult.toWallet);
    });

    test('a plain failure, or no answer at all', () {
      expect(
        paymentResultOfError(
          const ApiException(
            message: 'Transaction Failed, Please try again!',
            responseData: {'status': 0},
          ),
        ),
        PaymentResult.other,
      );
      expect(
        paymentResultOfError(const ApiException(message: 'No internet')),
        PaymentResult.other,
      );
    });
  });

  test('razorpayErrorDeletesBooking: only when nothing could be paid', () {
    expect(razorpayErrorDeletesBooking(Razorpay.PAYMENT_CANCELLED), isTrue);
    expect(razorpayErrorDeletesBooking(Razorpay.INVALID_OPTIONS), isTrue);
    expect(razorpayErrorDeletesBooking(Razorpay.NETWORK_ERROR), isFalse);
    expect(razorpayErrorDeletesBooking(Razorpay.UNKNOWN_ERROR), isFalse);
    expect(razorpayErrorDeletesBooking(Razorpay.TLS_ERROR), isFalse);
    expect(razorpayErrorDeletesBooking(null), isFalse);
  });

  test('isPendingPaymentStatus', () {
    expect(isPendingPaymentStatus('pending'), isTrue);
    expect(isPendingPaymentStatus('PENDING'), isTrue);
    expect(isPendingPaymentStatus(' Processing '), isTrue);
    expect(isPendingPaymentStatus('failed'), isFalse);
    expect(isPendingPaymentStatus('success'), isFalse);
    expect(isPendingPaymentStatus(''), isFalse);
  });
}
