// PestRaksh: the price a service card shows, as on the website
// (HomeVerticleProductCard.tsx: `bookable`, `priceVariant`, `showFromPrice`).
// A service has several packages (1 BHK, 2 BHK, ...). The card shows the
// cheapest one that can be booked, with "From" before it when the packages do
// not all cost the same. Adding to the cart is unchanged.
import 'package:customer/features/products/models/product_model.dart';

/// What a package costs: its sale price when it has one, else its price.
/// The same rule as the cards' own `hasDiscount`.
double packageEffectivePrice(Variants v) {
  final price = (v.price ?? 0).toDouble();
  final sale = (v.discountedPrice ?? 0).toDouble();
  return sale > 0 && sale < price ? sale : price;
}

/// The packages that can be booked now and have a price.
List<Variants> bookablePackages(List<Variants>? variants) => [
  for (final v in variants ?? const <Variants>[])
    if (v.isAvailable && packageEffectivePrice(v) > 0) v,
];

/// The cheapest bookable package, the one whose price a card shows. Null when
/// no package can be booked; the card then keeps the package it showed before.
Variants? cheapestPackage(List<Variants>? variants) {
  Variants? best;
  for (final v in bookablePackages(variants)) {
    if (best == null ||
        packageEffectivePrice(v) < packageEffectivePrice(best)) {
      best = v;
    }
  }
  return best;
}

/// "From ₹...": the service has several bookable packages and they do not all
/// cost the same.
bool showFromPrice(List<Variants>? variants) {
  final bookable = bookablePackages(variants);
  if (bookable.length < 2) return false;
  final first = packageEffectivePrice(bookable.first);
  return bookable.any((v) => packageEffectivePrice(v) != first);
}
