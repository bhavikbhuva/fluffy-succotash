// PestRaksh: the support number for Call and WhatsApp (APP_PLAN Phase 7), as
// the website's utils/whatsapp.ts.
import 'package:customer/commons/utils/support_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('supportDialNumber', () {
    test('a bare 10-digit Indian number gets 91 in front', () {
      expect(supportDialNumber('7201949464'), '917201949464');
    });

    test('spaces, dashes and + are dropped', () {
      expect(supportDialNumber('+91 72019 49464'), '917201949464');
      expect(supportDialNumber('72019-49464'), '917201949464');
    });

    test('a number with its country code stays as it is', () {
      expect(supportDialNumber('917201949464'), '917201949464');
    });

    test('empty or null gives empty', () {
      expect(supportDialNumber(null), '');
      expect(supportDialNumber(''), '');
      expect(supportDialNumber('n/a'), '');
    });
  });

  group('whatsAppUri', () {
    test('wa.me with the message encoded', () {
      expect(
        whatsAppUri(
          '917201949464',
          'Hi PestRaksh, I have a question about my booking ORD-1.',
        ).toString(),
        'https://wa.me/917201949464?text=Hi%20PestRaksh%2C%20I%20have%20a%20question%20about%20my%20booking%20ORD-1.',
      );
    });

    test('no number gives no link', () {
      expect(whatsAppUri('', 'Hi'), isNull);
    });
  });
}
