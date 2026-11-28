// PestRaksh: the refund choice when cancelling a paid booking (27 Nov 2026,
// as on the website): when it is asked, and the message after the cancel.
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/order_detail_cards.dart';
import 'package:flutter_test/flutter_test.dart';

/// The English texts of the two messages, as in `assets/languages/en.json`.
String _en(String key) => switch (key) {
  LanguageLabelKeys.refundDoneWallet =>
    'Booking cancelled. {amount} is in your PestRaksh wallet.',
  LanguageLabelKeys.refundDoneOriginal =>
    'Booking cancelled. {amount} will reach your card / UPI in 5–7 working days.',
  _ => key,
};

OrderData _order(String? method, dynamic total) => OrderData.fromJson({
  'id': 118,
  'payment_method': method,
  'final_total': total,
});

void main() {
  group('RefundChoice.offeredFor', () {
    test('asks for a booking paid at Razorpay, whatever the case', () {
      expect(RefundChoice.offeredFor(_order('razorpay', '1499.00')), isTrue);
      expect(RefundChoice.offeredFor(_order('Razorpay', 1499)), isTrue);
      expect(RefundChoice.offeredFor(_order('RAZORPAY', 0.5)), isTrue);
    });

    test('does not ask for cash, wallet, a zero total or no booking', () {
      expect(RefundChoice.offeredFor(_order('cod', '1499.00')), isFalse);
      expect(RefundChoice.offeredFor(_order('wallet', '1499.00')), isFalse);
      expect(RefundChoice.offeredFor(_order(null, '1499.00')), isFalse);
      expect(RefundChoice.offeredFor(_order('razorpay', '0.00')), isFalse);
      expect(RefundChoice.offeredFor(_order('razorpay', null)), isFalse);
      expect(RefundChoice.offeredFor(null), isFalse);
    });
  });

  group('RefundChoice.refundedRow', () {
    test('null when nothing came back', () {
      expect(RefundChoice.refundedRow([]), isNull);
      expect(RefundChoice.refundedRow([null]), isNull);
      expect(
        RefundChoice.refundedRow([
          {'id': 118},
          {'id': 118, 'refund_to': 'wallet', 'refund_total': 0},
        ]),
        isNull,
      );
    });

    test('the row with the largest refund, as number or text', () {
      final row = RefundChoice.refundedRow([
        null,
        {'refund_to': 'original', 'refund_total': '500.00'},
        {'refund_to': 'original', 'refund_total': 1499},
      ]);
      expect(row?['refund_total'], 1499);
    });
  });

  group('RefundChoice.doneMessage', () {
    test('the wallet', () {
      expect(
        RefundChoice.doneMessage(
          {'refund_to': 'wallet', 'refund_total': 1499.0},
          currency: '₹',
          translate: _en,
        ),
        'Booking cancelled. ₹1499 is in your PestRaksh wallet.',
      );
    });

    test('the card / UPI, with paise', () {
      expect(
        RefundChoice.doneMessage(
          {'refund_to': 'original', 'refund_total': '1499.50'},
          currency: '₹',
          translate: _en,
        ),
        'Booking cancelled. ₹1499.50 will reach your card / UPI in 5–7 working days.',
      );
    });

    test('anything but "original" is the wallet; no currency is ₹', () {
      expect(
        RefundChoice.doneMessage(
          {'refund_total': 200},
          currency: null,
          translate: _en,
        ),
        'Booking cancelled. ₹200 is in your PestRaksh wallet.',
      );
    });
  });
}
