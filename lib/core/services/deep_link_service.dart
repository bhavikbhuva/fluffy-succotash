import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter/material.dart';

/// Handles product deep links.
///
/// Incoming link patterns handled:
///   {scheme}://product/{productId}             — custom scheme from settings API
///   {AppConfig.webUrl}/product/{productId}  — HTTPS App Links / Universal Links
///
/// Share URL produced:
///   {AppConfig.webUrl}/product/{slug}?isMobile=true
///
/// The custom scheme (e.g. "snapbuy") is fetched from settings API field
/// `deep_link_scheme`. Must also be declared in AndroidManifest.xml and iOS Info.plist.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _productRepository = ProductRepository();
  StreamSubscription<Uri>? _sub;

  String get _scheme {
    final s = SettingsHiveBox.instance.getAppSettings()?.deeplinkSchema;
    return (s != null && s.isNotEmpty && s != 'null')
        ? s
        : AppConfig.deeplinkScheme;
  }

  /// Returns the share URL for a product.
  ///
  /// Always uses the HTTPS App Link on [AppConfig.webUrl] — not the raw
  /// custom scheme — so the shared link is tappable in chat apps and still
  /// opens something (website / App Link fallback) for recipients without
  /// the app installed. (Settings API's `website_mode` field isn't actually
  /// sent by the backend, so it can't be used to gate this.)
  String buildShareUrl(String slug, String productName) {
    return '${AppConfig.webUrl}/${AppConstants.deepLinkProductSegment}/$slug'
        '?${AppConstants.deepLinkIsMobileParam}=true';
  }

  final Set<String> _pending = {};
  String? _lastHandled;
  DateTime? _lastHandledAt;

  /// Must not block startup: on a cold start the splash (which signals
  /// [AppNavigator.markReady]) only appears after runApp, so awaiting
  /// readiness here would stall app launch until the timeout.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // Warm start (and, on app_links v6+, the initial link too).
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _onLink(uri, navigatorKey),
      onError: (_) {},
    );

    // Cold start — app launched via link. Fire-and-forget.
    unawaited(() async {
      try {
        final initial = await _appLinks.getInitialLink();
        logDebug('DeepLinkService: getInitialLink=$initial');
        if (initial != null) _onLink(initial, navigatorKey);
      } catch (_) {}
    }());
  }

  Future<void> _onLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) async {
    // Initial link can arrive via both getInitialLink and the stream, so
    // ignore the same uri while it's pending or just handled.
    final key = uri.toString();
    final last = _lastHandledAt;
    if (_pending.contains(key) ||
        (_lastHandled == key &&
            last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 3))) {
      return;
    }
    _pending.add(key);

    // Wait for splash to finish navigating so the product route lands on
    // top of the real first screen. Timeout is a safety net only.
    await AppNavigator.readyFuture.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
    _pending.remove(key);
    _lastHandled = key;
    _lastHandledAt = DateTime.now();
    _handle(uri, navigatorKey);
  }

  // Slug/id is the segment right after "product". It may be preceded by
  // other segments, e.g. a store prefix: /bhuj-quick/product/{slug}.
  /// PestRaksh: the booking id of an `order-detail/{id}` link, or null.
  String? _bookingIdFrom(List<String> segments) {
    final i = segments.indexOf('order-detail');
    if (i == -1 || i + 1 >= segments.length) return null;
    final id = segments[i + 1];
    return int.tryParse(id) == null ? null : id;
  }

  /// PestRaksh: opens booking [orderId] for a signed-in customer; otherwise
  /// the app just opens (the booking needs a login).
  Future<void> _openBooking(
    String orderId,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    var nav = navigatorKey.currentState;
    var attempts = 0;
    while (nav == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      nav = navigatorKey.currentState;
      attempts++;
    }
    nav?.pushNamed(
      RouteNames.orderDetail,
      arguments: OrderDetailArgs(orderId: orderId, isOngoing: true),
    );
  }

  String? _identifierFrom(List<String> segments) {
    final i = segments.indexOf(AppConstants.deepLinkProductSegment);
    if (i == -1 || i + 1 >= segments.length) return null;
    return segments[i + 1];
  }

  void _handle(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    logDebug('DeepLinkService: received uri=$uri');
    String? identifier;

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      // PestRaksh: a booking link (/order-detail/{id}, /kn/order-detail/{id})
      // opens the booking page in the app (APP_PLAN Phase 9).
      final bookingId = _bookingIdFrom(uri.pathSegments);
      if (bookingId != null) {
        _openBooking(bookingId, navigatorKey);
        return;
      }
      // https://web-domain/[store/]product/{slug-or-id}
      identifier = _identifierFrom(uri.pathSegments);
    } else if (uri.scheme == _scheme) {
      if (uri.host == AppConstants.deepLinkProductSegment &&
          uri.pathSegments.isNotEmpty) {
        // snapbuy://product/{slug-or-id}
        identifier = uri.pathSegments[0];
      } else {
        // snapbuy://web-domain/[store/]product/{slug-or-id}
        identifier = _identifierFrom(uri.pathSegments);
      }
    }

    logDebug('DeepLinkService: parsed identifier=$identifier');
    if (identifier != null && identifier.isNotEmpty) {
      _openProduct(identifier, navigatorKey);
    }
  }

  // The route only accepts a numeric productId, but shared links carry the
  // slug (see buildShareUrl) — resolve it via the API (which already
  // supports lookup by slug or id) before navigating.
  Future<void> _openProduct(
    String identifier,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    int? productId = int.tryParse(identifier);
    String? imageUrl;

    if (productId == null) {
      try {
        final detail = await _productRepository.getProductDetail(
          productId: identifier,
        );
        productId = detail.data?.id;
        imageUrl = detail.data?.imageUrl;
      } catch (e) {
        logDebug(
          'DeepLinkService: failed to resolve product "$identifier": $e',
        );
        return;
      }
    }

    if (productId == null) return;

    var nav = navigatorKey.currentState;
    var attempts = 0;
    while (nav == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      nav = navigatorKey.currentState;
      attempts++;
    }
    logDebug(
      'DeepLinkService: resolved productId=$productId nav=${nav != null}',
    );
    if (nav == null) return;

    nav.pushNamed(
      RouteNames.productDetail,
      arguments: ProductDetailArgs(productId: productId, imageUrl: imageUrl),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
