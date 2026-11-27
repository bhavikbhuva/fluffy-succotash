// PestRaksh: the price a service card shows: the cheapest bookable package,
// with "From" when the packages do not all cost the same (APP_PLAN Phase 2).
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/utils/package_price.dart';
import 'package:flutter_test/flutter_test.dart';

/// A package as the live product list sends it (26 Nov 2026). Every live
/// package has `stock` 999, `in_stock` true and no `attributes_text`.
Map<String, dynamic> _json(int id, String name, num price, num salePrice) => {
  'id': id,
  'name': name,
  'attributes_text': null,
  'price': price,
  'discounted_price': salePrice,
  'stock': 999,
  'in_stock': true,
};

/// Cockroach Control: the first six of its 19 packages, in server order. The
/// kitchen-only gel is the cheapest; a 1 BHK starts at ₹999.
final _cockroachControl = [
  _json(177, 'Kitchen & Utility (Gel Treatment Only)', 1199, 799),
  _json(90, '1 BHK (Single Service)', 1249, 999),
  _json(91, '2 BHK (Single Service)', 1599, 1299),
  _json(92, '3 BHK (Single Service)', 1849, 1499),
  _json(93, '4 BHK (Single Service)', 2099, 1699),
  _json(94, '5 BHK (Single Service)', 2349, 1899),
];

/// Office & Warehouse Pest Control: all eight packages, in server order. Its
/// two cheapest (188 and 192) cost the same.
final _officeAndWarehouse = [
  _json(188, 'Office – up to 999 sq ft', 1499, 999),
  _json(189, 'Office – 1,000 to 2,999 sq ft', 2499, 1999),
  _json(190, 'Office – 3,000 to 4,999 sq ft', 4999, 3999),
  _json(191, 'Office – 5,000 to 7,999 sq ft', 5999, 4499),
  _json(192, 'Warehouse – up to 999 sq ft', 1499, 999),
  _json(193, 'Warehouse – 1,000 to 2,999 sq ft', 2499, 1999),
  _json(194, 'Warehouse – 3,000 to 4,999 sq ft', 2999, 2499),
  _json(195, 'Warehouse – 5,000 to 7,999 sq ft', 3999, 3499),
];

// Some of them by name, with what each costs.
final _kitchen = _cockroachControl[0]; // ₹799
final _oneBhk = _cockroachControl[1]; // ₹999
final _twoBhk = _cockroachControl[2]; // ₹1299
final _threeBhk = _cockroachControl[3]; // ₹1499
final _office = _officeAndWarehouse[0]; // ₹999
final _biggerOffice = _officeAndWarehouse[1]; // ₹1999
final _warehouse = _officeAndWarehouse[4]; // ₹999

// Two more Cockroach Control packages, from further down its list.
final _oneBhkPremium = _json(
  171,
  '1 BHK (6D Premium Single Service)',
  1599,
  1199,
);
final _twoBhkPremium = _json(
  172,
  '2 BHK (6D Premium Single Service)',
  1949,
  1499,
);

const _outOfStock = {'in_stock': false, 'stock': 0};
const _noPrice = {'price': 0, 'discounted_price': 0};

/// One package, with [changes] laid over what the server sent.
Variants _package(
  Map<String, dynamic> json, [
  Map<String, dynamic> changes = const {},
]) => Variants.fromJson({...json, ...changes});

List<Variants> _packages(List<Map<String, dynamic>> json) => [
  for (final j in json) _package(j),
];

List<int?> _ids(List<Variants> packages) => [for (final p in packages) p.id];

void main() {
  group('packageEffectivePrice', () {
    double cost(Object? price, Object? salePrice) => packageEffectivePrice(
      Variants.fromJson({'price': price, 'discounted_price': salePrice}),
    );

    test('the sale price when it is above 0 and below the price', () {
      final costs = [
        for (final p in _packages(_cockroachControl)) packageEffectivePrice(p),
      ];
      expect(costs, [799, 999, 1299, 1499, 1699, 1899]);
      expect(cost(1249, 1248.5), 1248.5);
      expect(cost(1249, 0.5), 0.5);
    });

    test('the price when the sale price is 0 or not sent', () {
      expect(cost(1249, 0), 1249);
      expect(cost(1249, null), 1249);
      expect(packageEffectivePrice(Variants.fromJson({'price': 1249})), 1249);
      // fromJson reads a missing sale price as 0. A package built in the app
      // can hold a real null.
      expect(packageEffectivePrice(Variants(price: 1249)), 1249);
    });

    test('the price when the sale price equals the price', () {
      // How the server sends a package that has no discount.
      expect(cost(1249, 1249), 1249);
    });

    test('the price when the sale price is above the price', () {
      expect(cost(999, 1299), 999);
    });

    test('0 when the package has no price', () {
      expect(cost(0, 0), 0);
      expect(cost(null, null), 0);
      expect(packageEffectivePrice(Variants()), 0);
    });
  });

  group('bookablePackages', () {
    bool bookable(Map<String, dynamic> changes) =>
        bookablePackages([_package(_oneBhk, changes)]).isNotEmpty;

    test('all the live packages, in server order', () {
      final cockroach = bookablePackages(_packages(_cockroachControl));
      expect(_ids(cockroach), [177, 90, 91, 92, 93, 94]);
      final office = bookablePackages(_packages(_officeAndWarehouse));
      expect(_ids(office), [188, 189, 190, 191, 192, 193, 194, 195]);
    });

    test('in_stock decides when the server sends it', () {
      expect(bookable({'in_stock': true, 'stock': 0}), isTrue);
      expect(bookable({'in_stock': false, 'stock': 999}), isFalse);
    });

    test('without in_stock, stock above 0 decides', () {
      expect(bookable({'in_stock': null, 'stock': 999}), isTrue);
      expect(bookable({'in_stock': null, 'stock': 1}), isTrue);
      expect(bookable({'in_stock': null, 'stock': 0}), isFalse);
      expect(bookable({'in_stock': null, 'stock': null}), isFalse);
    });

    test('leaves out a package with price 0', () {
      expect(bookable(_noPrice), isFalse);
      final packages = [
        _package(_kitchen),
        _package(_oneBhk, _noPrice),
        _package(_twoBhk),
      ];
      expect(_ids(bookablePackages(packages)), [177, 91]);
    });

    test('empty for no list or an empty one', () {
      expect(bookablePackages(null), isEmpty);
      expect(bookablePackages([]), isEmpty);
    });
  });

  group('cheapestPackage', () {
    test('Cockroach Control: the kitchen-only gel, at 799', () {
      final packages = _packages(_cockroachControl);
      final cheapest = cheapestPackage(packages);
      expect(cheapest, same(packages.first));
      expect(cheapest!.id, 177);
      expect(packageEffectivePrice(cheapest), 799);
    });

    test('the cheapest even when it is not first in the list', () {
      // The server sends the cheapest first, unless a filter matched another.
      final packages = _packages(_cockroachControl);
      for (var i = 0; i < packages.length; i++) {
        final turned = [...packages.skip(i), ...packages.take(i)];
        expect(cheapestPackage(turned)!.id, 177, reason: 'turned by $i');
      }
      expect(cheapestPackage(packages.reversed.toList())!.id, 177);
    });

    test('goes by what a package costs, not by its price before the sale', () {
      // ₹1599 on sale at ₹1299 is cheaper than ₹1349 with no sale.
      final onSale = _package(_twoBhk);
      final noSale = _package(_oneBhk, {
        'price': 1349,
        'discounted_price': 1349,
      });
      expect(cheapestPackage([noSale, onSale]), same(onSale));
      expect(cheapestPackage([onSale, noSale]), same(onSale));
    });

    test('a package with sale price 0 is not taken as free', () {
      final noSale = _package(_kitchen, {'discounted_price': 0}); // ₹1199
      final oneBhk = _package(_oneBhk); // ₹999
      expect(cheapestPackage([noSale, oneBhk]), same(oneBhk));
    });

    test('of two at the same price, the first in the list', () {
      // Office and Warehouse "up to 999 sq ft" both cost ₹999.
      final packages = _packages(_officeAndWarehouse);
      expect(cheapestPackage(packages)!.id, 188);
      expect(cheapestPackage(packages.reversed.toList())!.id, 192);
    });

    test('skips a package that is out of stock', () {
      final packages = [
        _package(_kitchen, _outOfStock),
        _package(_oneBhk),
        _package(_twoBhk),
      ];
      expect(cheapestPackage(packages)!.id, 90);
    });

    test('without in_stock, skips a package with no stock', () {
      final packages = [
        _package(_kitchen, {'in_stock': null, 'stock': 0}),
        _package(_oneBhk, {'in_stock': null, 'stock': 999}),
        _package(_twoBhk, {'in_stock': null, 'stock': 999}),
      ];
      expect(cheapestPackage(packages)!.id, 90);
    });

    test('skips a package with price 0', () {
      final packages = [
        _package(_kitchen, _noPrice),
        _package(_oneBhk),
        _package(_twoBhk),
      ];
      expect(cheapestPackage(packages)!.id, 90);
    });

    test('null for no list or an empty one', () {
      expect(cheapestPackage(null), isNull);
      expect(cheapestPackage([]), isNull);
    });

    test('null when nothing is bookable', () {
      final packages = [
        _package(_kitchen, _outOfStock),
        _package(_oneBhk, {'in_stock': null, 'stock': 0}),
        _package(_twoBhk, _noPrice),
      ];
      expect(cheapestPackage(packages), isNull);
    });
  });

  group('showFromPrice', () {
    test('true for Cockroach Control, whose packages differ', () {
      expect(showFromPrice(_packages(_cockroachControl)), isTrue);
    });

    test('true for Office & Warehouse, though two packages cost the same', () {
      expect(showFromPrice(_packages(_officeAndWarehouse)), isTrue);
    });

    test('false for one package', () {
      expect(showFromPrice([_package(_kitchen)]), isFalse);
    });

    test('false for two bookable packages that cost the same', () {
      expect(showFromPrice([_package(_office), _package(_warehouse)]), isFalse);
    });

    test('false when only one of several is bookable', () {
      final packages = [
        _package(_kitchen),
        _package(_oneBhk, _outOfStock),
        _package(_twoBhk, {'in_stock': null, 'stock': 0}),
        _package(_threeBhk, _noPrice),
      ];
      expect(showFromPrice(packages), isFalse);
    });

    test('false for no list or an empty one', () {
      expect(showFromPrice(null), isFalse);
      expect(showFromPrice([]), isFalse);
    });

    test('true when the prices are equal but one has a lower sale price', () {
      // Both ₹1599: the 2 BHK on sale at ₹1299, the premium 1 BHK at ₹1199.
      final packages = [_package(_twoBhk), _package(_oneBhkPremium)];
      expect(showFromPrice(packages), isTrue);
    });

    test('false when the prices differ but the sale prices are the same', () {
      // ₹1849 and ₹1949, both on sale at ₹1499.
      final packages = [_package(_threeBhk), _package(_twoBhkPremium)];
      expect(showFromPrice(packages), isFalse);
    });

    test('a package with sale price 0 is compared by its price', () {
      final onSale = _package(_office); // ₹1499, on sale at ₹999
      final noSale = _package(_warehouse, {
        'price': 999,
        'discounted_price': 0,
      });
      final dearer = _package(_biggerOffice, {'discounted_price': 0}); // ₹2499
      expect(showFromPrice([onSale, noSale]), isFalse);
      expect(showFromPrice([noSale, dearer]), isTrue);
    });

    test('a package that cannot be booked does not count', () {
      // Two at ₹999 and one at ₹1999 that is out of stock.
      final office = _package(_office);
      final warehouse = _package(_warehouse);
      final soldOut = _package(_biggerOffice, _outOfStock);
      expect(showFromPrice([soldOut, office, warehouse]), isFalse);
      expect(showFromPrice([office, soldOut, warehouse]), isFalse);
      expect(showFromPrice([office, warehouse, soldOut]), isFalse);
    });

    test('true wherever the package at another price stands', () {
      final office = _package(_office); // ₹999
      final warehouse = _package(_warehouse); // ₹999
      final bigger = _package(_biggerOffice); // ₹1999
      expect(showFromPrice([bigger, office, warehouse]), isTrue);
      expect(showFromPrice([office, bigger, warehouse]), isTrue);
      expect(showFromPrice([office, warehouse, bigger]), isTrue);
    });
  });

  test('the list stays in the order it was given', () {
    final packages = _packages(_cockroachControl).reversed.toList();
    bookablePackages(packages);
    cheapestPackage(packages);
    showFromPrice(packages);
    expect(_ids(packages), [94, 93, 92, 91, 90, 177]);
  });
}
