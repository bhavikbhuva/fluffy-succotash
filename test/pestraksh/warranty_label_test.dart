// PestRaksh: a package's warranty on the service page, worded as on the
// website (services-frontend `serviceBadges.ts`, `warrantyLabel`).
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/features/products/utils/warranty_label.dart';
import 'package:flutter_test/flutter_test.dart';

/// The English texts of the two keys, as in `assets/languages/en.json`.
String _translate(String key) => switch (key) {
  LanguageLabelKeys.warrantyBadge => '{days}-day warranty',
  LanguageLabelKeys.warrantyBadgeWithRevisit =>
    '{days}-day warranty, free re-visit',
  _ => key,
};

void main() {
  group('warrantyLabel', () {
    test('no warranty: 0, negative or missing days', () {
      expect(warrantyLabel(_translate, days: 0), isNull);
      expect(warrantyLabel(_translate, days: 0, freeRevisits: 1), isNull);
      expect(warrantyLabel(_translate, days: -30, freeRevisits: 1), isNull);
      expect(warrantyLabel(_translate, days: null), isNull);
    });

    test('days without a free re-visit', () {
      expect(warrantyLabel(_translate, days: 30), '30-day warranty');
      expect(
        warrantyLabel(_translate, days: 30, freeRevisits: 0),
        '30-day warranty',
      );
      expect(
        warrantyLabel(_translate, days: 30, freeRevisits: null),
        '30-day warranty',
      );
    });

    test('days with a free re-visit', () {
      expect(
        warrantyLabel(_translate, days: 90, freeRevisits: 1),
        '90-day warranty, free re-visit',
      );
      expect(
        warrantyLabel(_translate, days: 90, freeRevisits: 2),
        '90-day warranty, free re-visit',
      );
    });

    test('{days} is replaced wherever the text puts it', () {
      String other(String key) => 'Warranty: {days} days';
      expect(warrantyLabel(other, days: 60), 'Warranty: 60 days');
      expect(warrantyLabel(_translate, days: 7), isNot(contains('{days}')));
    });
  });

  group('Variants.fromJson warranty fields', () {
    test('read when the server sends them', () {
      final v = Variants.fromJson({
        'id': 90,
        'name': '1 BHK (Single Service)',
        'warranty_days': 30,
        'free_revisits': '1',
        'visits_total': 3,
      });
      expect(v.warrantyDays, 30);
      expect(v.freeRevisits, 1);
      expect(v.visitsTotal, 3);
      expect(v.toJson(), containsPair('warranty_days', 30));
      expect(v.toJson(), containsPair('free_revisits', 1));
      expect(v.toJson(), containsPair('visits_total', 3));
    });

    test('0 when the server leaves them out', () {
      final v = Variants.fromJson({'id': 90, 'name': '1 BHK (Single Service)'});
      expect(v.warrantyDays, 0);
      expect(v.freeRevisits, 0);
      expect(v.visitsTotal, 0);
      expect(warrantyLabel(_translate, days: v.warrantyDays), isNull);
    });

    test('live packages today: warranty_days 0, so no label', () {
      final v = Variants.fromJson({
        'id': 90,
        'warranty_days': 0,
        'free_revisits': 0,
        'visits_total': 1,
      });
      expect(
        warrantyLabel(
          _translate,
          days: v.warrantyDays,
          freeRevisits: v.freeRevisits,
        ),
        isNull,
      );
    });
  });
}
