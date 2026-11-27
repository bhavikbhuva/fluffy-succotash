// PestRaksh: a service's packages grouped into plans (Admin → Services →
// Package plans), as the website's utils/packagePlans.ts.
import 'dart:convert';

import 'package:customer/features/products/models/package_plans_model.dart';
import 'package:customer/features/products/models/product_detail_model.dart'
    as detail;
import 'package:customer/features/products/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A package as the live API sends it (26–27 Nov 2026).
Map<String, dynamic> _json(
  int id,
  String name,
  String? planKey,
  String? sizeLabel, {
  num price = 1599,
  num salePrice = 1299,
}) => {
  'id': id,
  'name': name,
  'price': price,
  'discounted_price': salePrice,
  'in_stock': true,
  'plan_key': planKey,
  'size_label': sizeLabel,
};

Map<String, dynamic> _plan(String key, String name) => {
  'key': key,
  'name': name,
  'description': '',
};

List<Map<String, dynamic>> _bhk(int firstId, String planKey, int count) => [
  for (var i = 0; i < count; i++)
    _json(firstId + i, '${i + 1} BHK ($planKey)', planKey, '${i + 1} BHK'),
];

// Cockroach Control: four plans, 19 packages, in server order.
final _cockroachPlans = {
  'size_heading': 'Home size',
  'plans': [
    _plan('kitchen', 'Kitchen only'),
    _plan('single', 'Single service'),
    _plan('6d', '6D Premium'),
    _plan('amc', '6D Premium 1-Year AMC'),
  ],
};
final _cockroachVariants = [
  _json(
    177,
    'Kitchen & Utility (Gel Treatment Only)',
    'kitchen',
    'Kitchen & utility',
  ),
  ..._bhk(90, 'single', 6),
  ..._bhk(171, '6d', 6),
  ..._bhk(96, 'amc', 6),
];

// Flies Control: one plan, four packages.
final _fliesPlans = {
  'size_heading': 'Home size',
  'plans': [_plan('single', 'Single service')],
};
final _fliesVariants = _bhk(133, 'single', 4);

// Home Sanitization: apartments by BHK, villas by floor area.
final _sanitizationPlans = {
  'size_heading': 'Home size',
  'plans': [_plan('apartment', 'Apartment'), _plan('villa', 'Villa')],
};
final _sanitizationVariants = [
  ..._bhk(151, 'apartment', 5),
  _json(156, 'Villa 2,000 to 3,000 sq ft', 'villa', '2,000 to 3,000 sq ft'),
  _json(157, 'Villa 3,000 to 4,000 sq ft', 'villa', '3,000 to 4,000 sq ft'),
  _json(158, 'Villa 4,000 to 5,000 sq ft', 'villa', '4,000 to 5,000 sq ft'),
];

/// A service as the server sends it, through JSON so the maps have the
/// types `jsonDecode` gives.
Map<String, dynamic> _service(
  Object? plans,
  List<Map<String, dynamic>>? variants,
) =>
    jsonDecode(
          jsonEncode({
            'id': 1,
            'name': 'Service',
            'package_plans': ?plans,
            'variants': ?variants,
          }),
        )
        as Map<String, dynamic>;

ProductDataModel _product(
  Object? plans,
  List<Map<String, dynamic>>? variants,
) => ProductDataModel.fromJson(_service(plans, variants));

String _planKey(Variants v) => v.planKey ?? '';
String _sizeLabel(Variants v) => v.sizeLabel ?? '';

PackagePlanGroups<Variants>? _group(
  Object? plans,
  List<Map<String, dynamic>>? variants,
) {
  final product = _product(plans, variants);
  return groupPackagePlans<Variants>(
    product.packagePlans,
    product.variants,
    planKey: _planKey,
    sizeLabel: _sizeLabel,
  );
}

List<int?> _ids(List<Variants> packages) => [for (final p in packages) p.id];

/// [variants] with [changes] laid over the package [id].
List<Map<String, dynamic>> _change(
  List<Map<String, dynamic>> variants,
  int id,
  Map<String, dynamic> changes,
) => [
  for (final v in variants) v['id'] == id ? {...v, ...changes} : v,
];

void main() {
  group('the product models', () {
    test('the product list reads package_plans, plan_key and size_label', () {
      final product = _product(_cockroachPlans, _cockroachVariants);
      final config = product.packagePlans!;
      expect(config.sizeHeading, 'Home size');
      expect(
        [for (final p in config.plans) p.key],
        ['kitchen', 'single', '6d', 'amc'],
      );
      expect(
        [for (final p in config.plans) p.name],
        [
          'Kitchen only',
          'Single service',
          '6D Premium',
          '6D Premium 1-Year AMC',
        ],
      );
      expect(config.plans.first.description, '');
      final kitchen = product.variants!.first;
      expect(kitchen.id, 177);
      expect(kitchen.planKey, 'kitchen');
      expect(kitchen.sizeLabel, 'Kitchen & utility');
      final twoBhk = product.variants![2];
      expect(twoBhk.id, 91);
      expect(twoBhk.planKey, 'single');
      expect(twoBhk.sizeLabel, '2 BHK');
    });

    test('the service page reads package_plans, plan_key and size_label', () {
      final product = detail.ProductDetailDataModel.fromJson(
        _service(_sanitizationPlans, _sanitizationVariants),
      );
      final config = product.packagePlans!;
      expect(config.sizeHeading, 'Home size');
      expect([for (final p in config.plans) p.key], ['apartment', 'villa']);
      final villa = product.variants!.last;
      expect(villa.id, 158);
      expect(villa.planKey, 'villa');
      expect(villa.sizeLabel, '4,000 to 5,000 sq ft');
      expect(product.variants!.first.planKey, 'apartment');
      expect(product.variants!.first.sizeLabel, '1 BHK');
    });

    test('no package_plans gives null, on both models', () {
      expect(_product(null, _fliesVariants).packagePlans, isNull);
      expect(
        detail.ProductDetailDataModel.fromJson(
          _service(null, _fliesVariants),
        ).packagePlans,
        isNull,
      );
    });

    test('a package without plan_key or size_label reads them as null', () {
      final product = _product(null, [_json(90, '1 BHK', null, null)]);
      expect(product.variants!.single.planKey, isNull);
      expect(product.variants!.single.sizeLabel, isNull);
    });

    test('names, descriptions and the size heading are trimmed', () {
      final config = PackagePlansConfig.fromJson({
        'size_heading': '  Home size ',
        'plans': [
          {'key': 'single', 'name': ' Single service ', 'description': ' x '},
        ],
      });
      expect(config.sizeHeading, 'Home size');
      expect(config.plans.single.name, 'Single service');
      expect(config.plans.single.description, 'x');
    });
  });

  group('groupPackagePlans', () {
    test('Cockroach Control: four plans in server order', () {
      final groups = _group(_cockroachPlans, _cockroachVariants)!;
      expect(groups.sizeHeading, 'Home size');
      expect(
        [for (final p in groups.plans) p.key],
        ['kitchen', 'single', '6d', 'amc'],
      );
      expect(
        [for (final p in groups.plans) p.name],
        [
          'Kitchen only',
          'Single service',
          '6D Premium',
          '6D Premium 1-Year AMC',
        ],
      );
      expect([for (final p in groups.plans) p.variants.length], [1, 6, 6, 6]);
      expect(_ids(groups.plans[0].variants), [177]);
      expect(_ids(groups.plans[1].variants), [90, 91, 92, 93, 94, 95]);
      expect(_ids(groups.plans[2].variants), [171, 172, 173, 174, 175, 176]);
      expect(_ids(groups.plans[3].variants), [96, 97, 98, 99, 100, 101]);
    });

    test('the plans follow the config order, not the packages order', () {
      final groups = _group(
        _cockroachPlans,
        _cockroachVariants.reversed.toList(),
      )!;
      expect(
        [for (final p in groups.plans) p.key],
        ['kitchen', 'single', '6d', 'amc'],
      );
      expect(_ids(groups.plans[1].variants), [95, 94, 93, 92, 91, 90]);
    });

    test('Flies Control: one plan', () {
      final groups = _group(_fliesPlans, _fliesVariants)!;
      expect(groups.plans, hasLength(1));
      expect(groups.plans.single.key, 'single');
      expect(_ids(groups.plans.single.variants), [133, 134, 135, 136]);
    });

    test('Home Sanitization: apartments by BHK, villas by floor area', () {
      final groups = _group(_sanitizationPlans, _sanitizationVariants)!;
      expect([for (final p in groups.plans) p.key], ['apartment', 'villa']);
      expect(_ids(groups.plans[0].variants), [151, 152, 153, 154, 155]);
      expect(
        [for (final v in groups.plans[1].variants) v.sizeLabel],
        [
          '2,000 to 3,000 sq ft',
          '3,000 to 4,000 sq ft',
          '4,000 to 5,000 sq ft',
        ],
      );
    });

    test('null without a config', () {
      expect(_group(null, _cockroachVariants), isNull);
      expect(
        groupPackagePlans<Variants>(
          null,
          _product(null, _cockroachVariants).variants,
          planKey: _planKey,
          sizeLabel: _sizeLabel,
        ),
        isNull,
      );
    });

    test('null when the config has no plans', () {
      expect(
        _group({'size_heading': 'Home size', 'plans': []}, _fliesVariants),
        isNull,
      );
      expect(_group({'size_heading': 'Home size'}, _fliesVariants), isNull);
      expect(_group(<String, dynamic>{}, _fliesVariants), isNull);
    });

    test('null without packages', () {
      expect(_group(_cockroachPlans, null), isNull);
      expect(_group(_cockroachPlans, []), isNull);
    });

    test('null when a package has an unknown or missing plan_key', () {
      expect(
        _group(
          _cockroachPlans,
          _change(_cockroachVariants, 173, {'plan_key': 'gold'}),
        ),
        isNull,
      );
      expect(
        _group(
          _cockroachPlans,
          _change(_cockroachVariants, 173, {'plan_key': null}),
        ),
        isNull,
      );
      expect(
        _group(
          _cockroachPlans,
          _change(_cockroachVariants, 173, {'plan_key': ''}),
        ),
        isNull,
      );
    });

    test('null when a package has an empty, blank or missing size_label', () {
      for (final size in ['', '   ', null]) {
        expect(
          _group(
            _cockroachPlans,
            _change(_cockroachVariants, 99, {'size_label': size}),
          ),
          isNull,
          reason: 'size_label ${jsonEncode(size)}',
        );
      }
    });

    test('a plan with no packages is left out', () {
      final withoutKitchen = [
        for (final v in _cockroachVariants)
          if (v['plan_key'] != 'kitchen') v,
      ];
      final groups = _group(_cockroachPlans, withoutKitchen)!;
      expect([for (final p in groups.plans) p.key], ['single', '6d', 'amc']);
    });

    test('null when no plan has a package', () {
      // Cannot happen with a known plan_key on every package; an unknown one
      // already gives null. So this is the same as no packages.
      expect(_group(_fliesPlans, []), isNull);
    });

    test('a plan with an empty name is dropped', () {
      final plans = {
        'size_heading': 'Home size',
        'plans': [
          _plan('kitchen', 'Kitchen only'),
          _plan('single', 'Single service'),
          _plan('6d', '6D Premium'),
          _plan('amc', '  '),
        ],
      };
      final withoutAmc = [
        for (final v in _cockroachVariants)
          if (v['plan_key'] != 'amc') v,
      ];
      final groups = _group(plans, withoutAmc)!;
      expect(
        [for (final p in groups.plans) p.key],
        ['kitchen', 'single', '6d'],
      );
    });

    test('a plan with an empty name makes its packages unknown: null', () {
      final plans = {
        'size_heading': 'Home size',
        'plans': [
          _plan('kitchen', 'Kitchen only'),
          _plan('single', 'Single service'),
          _plan('6d', ''),
          _plan('amc', '6D Premium 1-Year AMC'),
        ],
      };
      expect(_group(plans, _cockroachVariants), isNull);
    });

    test('a plan with an empty key is dropped', () {
      final plans = {
        'size_heading': 'Home size',
        'plans': [_plan('', 'Nameless'), _plan('single', 'Single service')],
      };
      final groups = _group(plans, _fliesVariants)!;
      expect([for (final p in groups.plans) p.key], ['single']);
    });

    test('an empty size heading is kept as empty', () {
      final groups = _group({
        'plans': [_plan('single', 'Single service')],
      }, _fliesVariants)!;
      expect(groups.sizeHeading, '');
    });

    test('the same packages, not copies', () {
      final product = _product(_fliesPlans, _fliesVariants);
      final groups = groupPackagePlans<Variants>(
        product.packagePlans,
        product.variants,
        planKey: _planKey,
        sizeLabel: _sizeLabel,
      )!;
      expect(groups.plans.single.variants.first, same(product.variants!.first));
      expect(_ids(product.variants!), [133, 134, 135, 136]);
    });

    test('works on the service page model too', () {
      final product = detail.ProductDetailDataModel.fromJson(
        _service(_cockroachPlans, _cockroachVariants),
      );
      final groups = groupPackagePlans<detail.Variants>(
        product.packagePlans,
        product.variants,
        planKey: (v) => v.planKey ?? '',
        sizeLabel: (v) => v.sizeLabel ?? '',
      )!;
      expect([for (final p in groups.plans) p.variants.length], [1, 6, 6, 6]);
    });
  });

  group('planOf', () {
    final groups = _group(_cockroachPlans, _cockroachVariants)!;
    Variants package(int id) => [
      for (final p in groups.plans) ...p.variants,
    ].firstWhere((v) => v.id == id);

    test('the plan of the selected package', () {
      expect(groups.planOf(package(177), _planKey).key, 'kitchen');
      expect(groups.planOf(package(91), _planKey).key, 'single');
      expect(groups.planOf(package(172), _planKey).key, '6d');
      expect(groups.planOf(package(101), _planKey).key, 'amc');
    });

    test('the first plan when nothing is selected', () {
      expect(groups.planOf(null, _planKey).key, 'kitchen');
    });

    test('the first plan when the selected package has an unknown key', () {
      final stray = Variants.fromJson(_json(999, 'Gold', 'gold', '1 BHK'));
      expect(groups.planOf(stray, _planKey).key, 'kitchen');
      final noKey = Variants.fromJson(_json(998, 'None', null, '1 BHK'));
      expect(groups.planOf(noKey, _planKey).key, 'kitchen');
    });
  });

  group('samePackageSizeIn', () {
    final groups = _group(_cockroachPlans, _cockroachVariants)!;
    PackagePlan<Variants> plan(String key) =>
        groups.plans.firstWhere((p) => p.key == key);
    final singleTwoBhk = plan('single').variants[1];

    test('Cockroach single 2 BHK switched to 6D Premium: its 2 BHK', () {
      expect(singleTwoBhk.id, 91);
      final picked = samePackageSizeIn(plan('6d'), singleTwoBhk, _sizeLabel);
      expect(picked.id, 172);
      expect(picked.sizeLabel, '2 BHK');
      expect(samePackageSizeIn(plan('amc'), singleTwoBhk, _sizeLabel).id, 97);
    });

    test('switched to kitchen only, which has no 2 BHK: its first', () {
      expect(
        samePackageSizeIn(plan('kitchen'), singleTwoBhk, _sizeLabel).id,
        177,
      );
    });

    test('back from kitchen only to single service: its first', () {
      final kitchen = plan('kitchen').variants.single;
      expect(samePackageSizeIn(plan('single'), kitchen, _sizeLabel).id, 90);
    });

    test('the same plan keeps the selected package', () {
      expect(
        samePackageSizeIn(plan('single'), singleTwoBhk, _sizeLabel),
        same(singleTwoBhk),
      );
    });

    test('ignores case and spaces around the size', () {
      for (final size in ['2 bhk', '2 BHK ', '  2 Bhk', '\t2 BHK\n']) {
        final selected = Variants.fromJson(_json(91, '2 BHK', 'single', size));
        expect(
          samePackageSizeIn(plan('6d'), selected, _sizeLabel).id,
          172,
          reason: jsonEncode(size),
        );
      }
    });

    test('spaces inside the size still count', () {
      final selected = Variants.fromJson(_json(91, '2BHK', 'single', '2BHK'));
      expect(samePackageSizeIn(plan('6d'), selected, _sizeLabel).id, 171);
    });

    test('nothing selected gives the first package', () {
      expect(samePackageSizeIn<Variants>(plan('6d'), null, _sizeLabel).id, 171);
      expect(
        samePackageSizeIn<Variants>(plan('kitchen'), null, _sizeLabel).id,
        177,
      );
    });

    test('Home Sanitization: an apartment size is not in villas', () {
      final sanitization = _group(_sanitizationPlans, _sanitizationVariants)!;
      final twoBhk = sanitization.plans[0].variants[1];
      final villa = sanitization.plans[1];
      expect(samePackageSizeIn(villa, twoBhk, _sizeLabel).id, 156);
    });
  });
}
