import 'dart:io';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:customer/features/orders/repositories/order_repository.dart';
import 'package:customer/features/payment_method/models/enums/transaction_type.dart';
import 'package:customer/features/payment_method/models/payment_form_payload.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/payment_method/repositories/payment_repository.dart';
import 'package:customer/features/payment_method/utils/payment_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ───────────────────────────────────────────────────────────────────

sealed class PaymentState {}

final class PaymentInitial extends PaymentState {}

final class PaymentProcessing extends PaymentState {}

/// WebView-based gateways: open [url] in WebView.
final class PaymentWebViewReady extends PaymentState {
  PaymentWebViewReady({
    required this.url,
    required this.orderId,
    this.orderItemId = '',
    required this.paymentType,
    required this.gateway,
    this.extra,
    this.merchantOrderId,
    this.formPayload,
  });

  final String url;
  final String orderId;
  final String orderItemId;
  final String paymentType;
  final PaymentGatewayType gateway;
  final Map<String, dynamic>? extra;
  final String? merchantOrderId; // PhonePe
  final PaymentFormPayload? formPayload; // PayU — posted instead of [url]
}

/// SDK-based gateways (Stripe / Razorpay / Paystack).
final class PaymentSdkReady extends PaymentState {
  PaymentSdkReady({
    required this.orderId,
    this.orderItemId = '',
    required this.gateway,
    this.clientSecret,
    this.razorpayOrderId,
    this.transactionId,
  });

  final String orderId;
  final String orderItemId;
  final PaymentGatewayType gateway;
  final String? clientSecret;
  final String? razorpayOrderId;

  final String? transactionId;
}

final class PaymentSuccess extends PaymentState {
  PaymentSuccess(this.orderId, {this.orderItemId = '', this.infoMessage});

  final String orderId;
  final String orderItemId;

  /// PestRaksh: the server's note when the payment is still being confirmed
  /// (`PAYMENT_PROCESSING`). The booking stands, so the customer goes on to it
  /// like after a payment, and sees this as information.
  final String? infoMessage;
}

/// PestRaksh: the payment reached the server after the booking was cancelled,
/// and the money went to the wallet (`PAYMENT_TO_WALLET`). Not a failure:
/// shown as information, and nothing asks for payment again.
final class PaymentInfo extends PaymentState {
  PaymentInfo(this.message);

  final String message;
}

final class PaymentError extends PaymentState {
  PaymentError(this.message);

  final String message;
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({
    PaymentRepository? repository,
    AuthRepository? authRepository,
    OrderRepository? orderRepository,
  }) : _repository = repository ?? PaymentRepository(),
       _authRepository = authRepository ?? AuthRepository(),
       _orderRepository = orderRepository ?? OrderRepository(),
       super(PaymentInitial());

  final PaymentRepository _repository;
  final AuthRepository _authRepository;
  final OrderRepository _orderRepository;

  /// Deletes an order left in "awaiting payment" state when a gateway
  /// attempt fails/is cancelled, so it doesn't linger as an orphan order.
  /// Swallows errors — cleanup must not block showing the payment error.
  /// No-op for wallet top-up (empty [orderId]) — there is no order to delete.
  Future<void> deleteOrder(String orderId) async {
    if (orderId.trim().isEmpty) return;
    try {
      await _orderRepository.deleteOrder(orderId: orderId);
    } catch (_) {}
  }

  /// Payment flows do multiple awaits (network + local storage) — the screen
  /// can be popped/disposed mid-flight, closing this cubit. Emitting after
  /// close throws "Bad state: Cannot emit new states after calling close",
  /// so every emit goes through this guard instead of calling emit directly.
  void _emit(PaymentState state) {
    if (isClosed) return;
    emit(state);
  }

  /// Initiates payment for the selected [method].
  /// For wallet top-up pass extra = {ApiParameters.amount: '100',
  /// ApiParameters.type: TransactionType.wallet.apiValue}.
  Future<void> initiatePayment({
    required String orderId,
    String orderItemId = '',
    required PaymentMethodItem method,
    Map<String, dynamic>? extra,
  }) async {
    if (method.flowType == PaymentFlowType.cod) {
      _emit(PaymentSuccess(orderId, orderItemId: orderItemId));
      return;
    }

    // Paystack SDK handles transaction directly — no backend initiate needed.
    // Razorpay + Stripe go through initiateTransaction below — backend creates the
    // PaymentIntent server-side and returns the same client_secret/id Stripe's
    // own API would, so the app never calls api.stripe.com directly.
    if (method.type == PaymentGatewayType.paystack) {
      _emit(
        PaymentSdkReady(
          orderId: orderId,
          orderItemId: orderItemId,
          gateway: method.type,
        ),
      );
      return;
    }

    _emit(PaymentProcessing());
    try {
      final isWallet =
          TransactionType.fromRaw(extra?[ApiParameters.type]) ==
          TransactionType.wallet;

      final String requestFrom = AppConstants.platformType;

      final Map<String, dynamic> params = isWallet
          ? {
              ApiParameters.paymentMethod: method.apiValue,
              ApiParameters.walletAmount: extra![ApiParameters.amount]
                  .toString(),
              ApiParameters.type: TransactionType.wallet.apiValue,
              ApiParameters.requestFrom: requestFrom,
            }
          : {
              ApiParameters.orderId: orderId,
              ApiParameters.paymentMethod: method.apiValue,
              ApiParameters.type: TransactionType.order.apiValue,
              ApiParameters.requestFrom: requestFrom,
              ...?extra,
            };

      final response = await _repository.initiateTransaction(params: params);

      if (method.flowType == PaymentFlowType.webview) {
        // PayU sends a form to auto-submit instead of a redirect URL.
        final formPayload = response.data?.formPayload;
        final url = response.data?.paymentUrl ?? formPayload?.action ?? '';
        if (url.isEmpty) {
          await deleteOrder(orderId);
          _emit(
            PaymentError(
              LocalizationService.instance.translate(
                LanguageLabelKeys.paymentUrlNotReceived,
              ),
            ),
          );
          return;
        }
        _emit(
          PaymentWebViewReady(
            url: url,
            orderId: orderId,
            orderItemId: orderItemId,
            paymentType: method.apiValue,
            gateway: method.type,
            extra: extra,
            merchantOrderId:
                response.data?.merchantOrderId ?? response.data?.transactionId,
            formPayload: formPayload,
          ),
        );
      } else {
        _emit(
          PaymentSdkReady(
            orderId: orderId,
            orderItemId: orderItemId,
            gateway: method.type,
            clientSecret: response.data?.clientSecret,
            razorpayOrderId: response.data?.razorpayOrderId,
            transactionId: response.data?.transactionId,
          ),
        );
      }
    } on ApiException catch (e) {
      // PestRaksh: "being confirmed" or "moved to the wallet" means money was
      // paid: never delete the booking for them.
      if (paymentResultOfError(e) == .other) {
        await deleteOrder(orderId);
        _emit(PaymentError(e.message));
      } else {
        // PestRaksh: paid (being confirmed, or moved to the wallet): say so as
        // information, not as an error.
        _emit(PaymentInfo(e.message));
      }
    } catch (_) {
      await deleteOrder(orderId);
      _emit(
        PaymentError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Called after SDK payment completes to record the transaction.
  /// For wallet top-up pass extra = {ApiParameters.amount: '100',
  /// ApiParameters.type: TransactionType.wallet.apiValue}.
  Future<void> addTransaction({
    required String orderId,
    String orderItemId = '',
    required String paymentType,
    required String txnId,
    required bool success,
    Map<String, dynamic>? extra,
    bool callApi = true,
    // PestRaksh: false keeps the booking after a failed payment, and the
    // server cancels it if it stays unpaid. Razorpay no longer uses it: its
    // error comes after the window has closed, so the booking is deleted
    // (see `razorpayErrorDeletesBooking`).
    bool deleteOrderOnFailure = true,
  }) async {
    _emit(PaymentProcessing());
    // PestRaksh: outside the try, so the ApiException branch can read it.
    final isWallet =
        TransactionType.fromRaw(extra?[ApiParameters.type]) ==
        TransactionType.wallet;
    try {
      final statusValue = success ? 'success' : 'failed';
      final os = Platform.operatingSystem;
      final deviceType = os[0].toUpperCase() + os.substring(1);
      final appVersion = (await PackageInfo.fromPlatform()).version;

      final Map<String, dynamic> params;
      if (isWallet) {
        params = {
          ApiParameters.walletAmount: extra![ApiParameters.amount].toString(),
          ApiParameters.deviceType: deviceType,
          ApiParameters.appVersion: appVersion,
          ApiParameters.transactionId: txnId,
          ApiParameters.paymentMethod: paymentType,
          ApiParameters.type: TransactionType.wallet.apiValue,
        };
      } else {
        params = {
          ApiParameters.orderId: orderId,
          ApiParameters.paymentMethod: paymentType,
          ApiParameters.transactionId: txnId,
          ApiParameters.status: statusValue,
          ApiParameters.type: TransactionType.order.apiValue,
          ApiParameters.deviceType: deviceType,
          ApiParameters.appVersion: appVersion,
          ...?extra,
        };
      }

      if (success) {
        if (callApi) await _repository.addTransaction(params: params);
        await _refreshUserDetails();
        _emit(PaymentSuccess(orderId, orderItemId: orderItemId));
      } else {
        if (!isWallet && deleteOrderOnFailure) await deleteOrder(orderId);
        _emit(
          PaymentError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.paymentFailedTryAgain,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      // PestRaksh: two answers to a booking's payment are not failures.
      // Being confirmed: the booking stands, go on to it. Moved to the
      // wallet: say so and refresh the balance. Neither asks to pay again.
      final result = isWallet ? PaymentResult.other : paymentResultOfError(e);
      switch (result) {
        case .processing:
          await _refreshUserDetails();
          _emit(
            PaymentSuccess(
              orderId,
              orderItemId: orderItemId,
              infoMessage: _resultMessage(
                e,
                LanguageLabelKeys.paymentPendingCheckLater,
              ),
            ),
          );
        case .toWallet:
          await _refreshUserDetails();
          _emit(
            PaymentInfo(
              _resultMessage(e, LanguageLabelKeys.moneyAddedToWallet),
            ),
          );
        case .other:
          _emit(PaymentError(e.message));
      }
    } catch (_) {
      _emit(
        PaymentError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// PestRaksh: the server's own words for [PaymentResult.processing] and
  /// [PaymentResult.toWallet]; the app has no texts of its own for them yet.
  /// [fallbackKey] when the server sent only the code, or nothing.
  String _resultMessage(ApiException e, String fallbackKey) {
    // Not e.message: with no message from the server it is "something went
    // wrong".
    final message =
        (e.responseData == null
                ? e.message
                : e.responseData!['message']?.toString() ?? '')
            .trim();
    if (message.isEmpty || paymentResultOf(message: message) != .other) {
      return LocalizationService.instance.translate(fallbackKey);
    }
    return message;
  }

  static const _phonePePollInterval = Duration(seconds: 3);
  static const _phonePeMaxPolls = 40; // ~2 min

  /// PhonePe: check order status after webview returns SUCCESS / PENDING.
  /// Keeps polling while the status is PENDING.
  Future<void> checkPhonePeStatus({
    required String orderId,
    String orderItemId = '',
    required String transactionId,
    Map<String, dynamic>? extra,
  }) async {
    _emit(PaymentProcessing());
    try {
      final isWallet =
          TransactionType.fromRaw(extra?[ApiParameters.type]) ==
          TransactionType.wallet;

      var dataStatus = '';
      for (var attempt = 0; attempt < _phonePeMaxPolls; attempt++) {
        if (isClosed) return;
        if (attempt > 0) await Future.delayed(_phonePePollInterval);

        final response = await _repository.orderStatusPhonePe(
          transactionId: transactionId,
          orderId: orderId,
          isWallet: isWallet,
        );

        final apiStatus = response['status']?.toString() ?? '0';
        if (apiStatus != '1') {
          _emit(
            PaymentError(
              response['message']?.toString() ??
                  LocalizationService.instance.translate(
                    LanguageLabelKeys.phonePeStatusCheckFailed,
                  ),
            ),
          );
          return;
        }

        dataStatus =
            (response['data'] as Map<String, dynamic>?)?['status']
                ?.toString() ??
            '';
        if (dataStatus != 'PENDING') break;
      }

      switch (dataStatus) {
        case 'SUCCESS':
          await _refreshUserDetails();
          _emit(PaymentSuccess(orderId, orderItemId: orderItemId));
        case 'COMPLETED':
          await _refreshUserDetails();
          _emit(PaymentSuccess(orderId, orderItemId: orderItemId));
        case 'FAILED':
        case 'PAYMENT_ERROR':
          _emit(
            PaymentError(
              LocalizationService.instance.translate(
                LanguageLabelKeys.phonePePaymentFailed,
              ),
            ),
          );
        case 'PAYMENT_DECLINED':
          _emit(
            PaymentError(
              LocalizationService.instance.translate(
                LanguageLabelKeys.phonePePaymentDeclined,
              ),
            ),
          );
        case 'PAYMENT_CANCELLED':
          _emit(
            PaymentError(
              LocalizationService.instance.translate(
                LanguageLabelKeys.phonePePaymentCancelled,
              ),
            ),
          );
        case 'PENDING':
          // Still pending after polling — order kept, backend settles it.
          _emit(
            PaymentError(
              LocalizationService.instance.translate(
                LanguageLabelKeys.phonepePaymentPending,
              ),
            ),
          );
        default:
          _emit(
            PaymentError(
              LocalizationService.instance
                  .translate(LanguageLabelKeys.phonePePaymentStatus)
                  .replaceAll('{status}', dataStatus),
            ),
          );
      }
    } on ApiException catch (e) {
      _emit(PaymentError(e.message));
    } catch (_) {
      _emit(
        PaymentError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Refresh user details (wallet balance) after successful payment and
  /// persist to local storage. Swallows errors — refresh must not fail payment.
  Future<void> _refreshUserDetails() async {
    try {
      final user = await _authRepository.getProfile();
      if (user.data?.id != null) {
        await AuthHiveBox.instance.updateUserSession(updated: user);
      }
    } catch (_) {}
  }

  Future<void> onWebViewSuccess(
    String orderId, {
    String orderItemId = '',
  }) async {
    _emit(PaymentProcessing());
    await _refreshUserDetails();
    _emit(PaymentSuccess(orderId, orderItemId: orderItemId));
  }

  void onWebViewFailed(String message) => _emit(PaymentError(message));
  void reset() => _emit(PaymentInitial());
}
