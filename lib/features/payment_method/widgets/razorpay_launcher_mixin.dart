import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/models/payment_args.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:customer/features/payment_method/utils/payment_result.dart';
import 'package:customer/features/payment_method/widgets/payment_result_info.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

mixin RazorpayLauncherMixin<T extends StatefulWidget> on State<T> {
  /// Order/amount/currency for the in-flight payment attempt — provided by
  /// the host screen (payment methods list, or checkout paying directly).
  PaymentArgs get launcherArgs;

  late final Razorpay razorpay;

  void initRazorpay() {
    razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
  }

  void disposeRazorpay() => razorpay.clear();

  Future<void> _onRazorpaySuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    final cubit = context.read<PaymentCubit>();
    await cubit.addTransaction(
      orderId: launcherArgs.orderId,
      orderItemId: launcherArgs.orderItemId,
      paymentType: PaymentGatewayType.razorpay.apiValue,
      txnId: response.paymentId ?? '',
      success: true,
      extra: launcherArgs.extra,
    );
    // PestRaksh: "being confirmed" / "moved to the wallet" as information.
    if (mounted) showPaymentResultInfo(context, cubit.state);
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    context.read<PaymentCubit>().addTransaction(
      orderId: launcherArgs.orderId,
      orderItemId: launcherArgs.orderItemId,
      paymentType: PaymentGatewayType.razorpay.apiValue,
      txnId: response.error?['metadata']?['payment_id']?.toString() ?? '',
      success: false,
      extra: launcherArgs.extra,
      // PestRaksh: the error comes only after the window has closed, so the
      // app can no longer pay this booking: delete it, as the website does
      // when its window closes. See [razorpayErrorDeletesBooking].
      deleteOrderOnFailure: razorpayErrorDeletesBooking(response.code),
    );
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse response) {}

  void launchRazorpay(
    PaymentSdkReady sdkState,
    PaymentMethodsData? methodsData,
  ) {
    final key = methodsData?.razorpayKey ?? '';
    if (key.isEmpty) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.razorpayKeyNotConfigured),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
      return;
    }

    // Backend-created Razorpay order ("order_…") from initiate_transaction.
    // Without it the payment stays "authorized" (never auto-captured) and
    // backend verification of add_transaction fails.
    final razorpayOrderId = (sdkState.razorpayOrderId?.isNotEmpty ?? false)
        ? sdkState.razorpayOrderId!
        : (sdkState.transactionId ?? '');
    if (razorpayOrderId.isEmpty) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.somethingWentWrong),
        type: SnackBarType.error,
      );
      context.read<PaymentCubit>().deleteOrder(launcherArgs.orderId);
      context.read<PaymentCubit>().reset();
      return;
    }

    final options = <String, dynamic>{
      'key': key,
      'order_id': razorpayOrderId,
      'amount': (launcherArgs.amount * 100).toInt(),
      // PestRaksh: the top of Razorpay's window is the business, not the
      // customer (it was left blank), and the line under it says what is
      // being paid for, as on the website (services-frontend 6a291a8).
      'name': AppConfig.appName,
      'description': _razorpayDescription(),
      'prefill': {
        // PestRaksh: the customer's own details, so they need not type them.
        'name': launcherArgs.userName ?? '',
        'contact': launcherArgs.userPhone ?? '',
        'email': launcherArgs.userEmail ?? '',
      },
      'external': {'wallets': []},
    };
    // PestRaksh: the logo from the admin's settings, shown in the window as
    // on the website. Left out when there is none.
    final logo = SettingsHiveBox.instance.getAppSettings()?.webLogo?.trim();
    if (logo != null && logo.startsWith('http')) options['image'] = logo;
    try {
      razorpay.open(options);
    } catch (e) {
      AppSnackBar.show(
        context: context,
        message: e.toString(),
        type: SnackBarType.error,
      );
    }
  }

  /// PestRaksh: "Booking #`id`" for a booking, or the wallet text for a
  /// wallet top-up (which has no booking).
  String _razorpayDescription() {
    if (launcherArgs.isWalletTopUp) {
      return context.translate(
        LanguageLabelKeys.addMoneyToWallet,
        fallback: 'PestRaksh wallet',
      );
    }
    final booking = context.translate(
      LanguageLabelKeys.booking,
      fallback: 'Booking',
    );
    return '$booking #${launcherArgs.orderId}';
  }
}
