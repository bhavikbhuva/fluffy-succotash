import 'package:flutter/widgets.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';

class ClarityService {
  ClarityService._();

  /// True when the SDK was wrapped around the app at boot (see [isEnabledInCache]).
  static bool _active = false;

  /// Cached `clarity_status_customer == '1'`. Checked at boot so the SDK is
  /// not even initialised when Clarity is off (no session capture at all).
  /// Toggling takes effect on next app launch.
  static bool get isEnabledInCache =>
      SettingsHiveBox.instance.getAppSettings()?.clarityStatusCustomer == '1';

  /// Wraps [app] with Clarity only if enabled in cached settings.
  static Widget wrap(Widget app) {
    _active = isEnabledInCache;
    return _active ? ClarityWidget(app: app, clarityConfig: config) : app;
  }

  /// Project id from cached settings (`clarity_project_id_customer`),
  /// falls back to [AppConfig.clarityProjectId] when empty/unset.
  static ClarityConfig get config {
    final customProjectId = SettingsHiveBox.instance
        .getAppSettings()
        ?.clarityProjectIdCustomer;
    final projectId =
        (customProjectId != null && customProjectId.trim().isNotEmpty)
        ? customProjectId
        : AppConfig.clarityProjectId;
    return ClarityConfig(projectId: projectId);
  }

  static void sendCustomEvent(String name) {
    if (_active) Clarity.sendCustomEvent(name);
  }

  static void setCustomTag(String key, String value) {
    if (_active) Clarity.setCustomTag(key, value);
  }

  static void setCurrentScreenName(String? screenName) {
    if (_active) Clarity.setCurrentScreenName(screenName);
  }

  static void pause() {
    if (_active) Clarity.pause();
  }

  static void resume() {
    if (_active) Clarity.resume();
  }

  /// Applies the `clarity_status_customer` flag from settings ("1" = on, else off).
  static void applyStatus(String? status) {
    if (status == '1') {
      resume();
    } else {
      pause();
    }
  }
}
