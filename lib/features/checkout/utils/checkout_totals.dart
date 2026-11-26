import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/promo_code/models/enums/promo_apply_type.dart';
import 'package:customer/features/promo_code/models/enums/promo_discount_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';

/// Amount an applied promo takes off the bill. A free-delivery promo comes
/// back with `discount: 0` (only a `free_delivery` flag), so its value is
/// the cart's delivery charge rather than [PromoCodeData.discount].
double resolveCheckoutPromoDiscount({
  required CartData cartData,
  required PromoCodeData promo,
}) {
  if (promo.discountTypeEnum == PromoDiscountType.freeDelivery) {
    final delivery = cartData.deliveryCharges?.amount ?? 0.0;
    return promo.discount > 0 ? promo.discount : delivery;
  }
  return promo.discount;
}

/// Post-promo payable total. A wallet promo (`discount_apply_type: wallet`)
/// is credited as wallet cashback after delivery rather than subtracted
/// here, an instant promo is — mirrors `CheckoutBillDetailsSection`'s
/// `_PromoTotals`. Every screen/widget computing what's actually charged
/// (place-order payload, payment-method gating, the sticky bar's displayed
/// total) must derive it from here so the displayed total and the amount
/// actually sent to the gateway can't drift.
double resolveCheckoutPostPromoTotal({
  required CartData cartData,
  PromoCodeData? appliedPromo,
}) {
  final orderAmount = cartData.totalAmount ?? 0.0;
  final promo = appliedPromo;
  if (promo == null) return orderAmount;
  if (promo.discountApplyTypeEnum == PromoApplyType.wallet) return orderAmount;
  return orderAmount -
      resolveCheckoutPromoDiscount(cartData: cartData, promo: promo);
}

/// Total amount saved on this order — cart-level savings plus an instant
/// promo's discount (a wallet promo isn't counted here since it's
/// credited as wallet cashback instead). Mirrors
/// `CheckoutBillDetailsSection`'s `_PromoTotals.saved`.
num resolveCheckoutSavedAmount({
  required CartData cartData,
  PromoCodeData? appliedPromo,
}) {
  final promo = appliedPromo;
  final isWalletPromo =
      promo != null && promo.discountApplyTypeEnum == PromoApplyType.wallet;
  return (cartData.savedAmount ?? 0) +
      (promo != null && !isWalletPromo
          ? resolveCheckoutPromoDiscount(cartData: cartData, promo: promo)
          : 0);
}

/// True when the wallet balance alone covers [postPromoTotal] and the user
/// has opted to use it — no separate payment method is needed.
bool resolveCheckoutWalletCoversFull({
  required CartData cartData,
  required bool useWallet,
  required double postPromoTotal,
}) => useWallet && (cartData.userBalance ?? 0.0) >= postPromoTotal;

/// Portion of [postPromoTotal] paid from the wallet — capped at the
/// available balance so any remainder still goes through the selected
/// payment method.
double resolveCheckoutWalletAmountUsed({
  required CartData cartData,
  required bool useWallet,
  required double postPromoTotal,
}) {
  if (!useWallet) return 0.0;
  final balance = cartData.userBalance ?? 0.0;
  if (balance <= 0) return 0.0;
  return balance >= postPromoTotal ? postPromoTotal : balance;
}
