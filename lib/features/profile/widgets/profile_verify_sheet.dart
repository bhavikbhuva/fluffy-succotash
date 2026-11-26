import 'dart:async';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/auth/widgets/auth_otp_fields.dart';
import 'package:customer/features/auth/widgets/auth_resend_section.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Asks for the 6 digit code sent to [target] and resolves `true` once
/// [onVerify] accepts it. [onVerify] throws [ApiException] on a wrong code;
/// the message is shown and the customer can retry or resend.
Future<bool?> showProfileVerifySheet(
  BuildContext context, {
  required String title,
  required String target,
  required Future<void> Function(String code) onVerify,
  required Future<void> Function() onResend,
}) {
  return showAppBottomSheet<bool>(
    context,
    title: title,
    builder: (_) => _ProfileVerifySheet(
      target: target,
      onVerify: onVerify,
      onResend: onResend,
    ),
  );
}

class _ProfileVerifySheet extends StatefulWidget {
  final String target;
  final Future<void> Function(String code) onVerify;
  final Future<void> Function() onResend;

  const _ProfileVerifySheet({
    required this.target,
    required this.onVerify,
    required this.onResend,
  });

  @override
  State<_ProfileVerifySheet> createState() => _ProfileVerifySheetState();
}

class _ProfileVerifySheetState extends State<_ProfileVerifySheet> {
  final _otpController = TextEditingController();
  Duration _resendTimer = Duration(seconds: AppConfig.otpResendTimerSeconds);
  Timer? _timer;
  bool _isLoading = false;

  /// True after an HTTP 429: Verify and Resend stay locked until the timer ends.
  bool _rateLimited = false;

  /// Shown inside the sheet (a snackbar would sit behind it).
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer({int? seconds}) {
    _timer?.cancel();
    setState(
      () => _resendTimer = Duration(
        seconds: seconds ?? AppConfig.otpResendTimerSeconds,
      ),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return _timer?.cancel();
      setState(() {
        if (_resendTimer.inSeconds <= 1) {
          _resendTimer = Duration.zero;
          _rateLimited = false;
          _timer?.cancel();
        } else {
          _resendTimer = Duration(seconds: _resendTimer.inSeconds - 1);
        }
      });
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    if (e is ApiException && e.isRateLimited) {
      // Too many attempts: lock the sheet for Retry-After (default 60s).
      _rateLimited = true;
      _startTimer(
        seconds: e.retryAfterSeconds ?? AppConfig.otpResendTimerSeconds,
      );
    }
    setState(
      () => _errorMessage = e is ApiException
          ? e.message
          : LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
    );
  }

  Future<void> _verify() async {
    final code = _otpController.text;
    if (code.length != 6) {
      setState(
        () => _errorMessage = context.translate(
          LanguageLabelKeys.enterSixDigitOtp,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.onVerify(code);
      if (mounted) AppNavigator.pop(context, true);
    } catch (e) {
      _otpController.clear();
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    try {
      setState(() => _errorMessage = null);
      await widget.onResend();
      _otpController.clear();
      _startTimer();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          context
              .translate(LanguageLabelKeys.enterCodeSentTo)
              .replaceAll('{target}', widget.target),
          textAlign: TextAlign.center,
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
        AppSpacing.h24,
        Center(
          child: AuthOtpFields(
            controller: _otpController,
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            onCompleted: (_) => _verify(),
          ),
        ),
        if (_errorMessage != null) ...[
          AppSpacing.h12,
          AppText(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
        ],
        AppSpacing.h16,
        AuthResendSection(resendTimer: _resendTimer, onResend: _resend),
        AppSpacing.h24,
        AppButton(
          label: context.translate(LanguageLabelKeys.verify),
          onPressed: _rateLimited ? null : _verify,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
