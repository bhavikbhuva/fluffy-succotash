// PestRaksh: "Call us" and "WhatsApp us" to the support number (APP_PLAN
// Phase 7). Hidden when Settings has no support number.
import 'package:customer/commons/utils/support_contact.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// The two buttons side by side; [whatsAppText] is the message WhatsApp
/// opens with (null: no WhatsApp button).
class SupportContactButtons extends StatelessWidget {
  const SupportContactButtons({super.key, this.whatsAppText});

  final String? whatsAppText;

  @override
  Widget build(BuildContext context) {
    if (currentSupportNumber().isEmpty) return const SizedBox.shrink();
    return Row(
      spacing: ThemeConstants.spaceM,
      children: [
        Expanded(
          child: _ContactButton(
            icon: Icons.call_outlined,
            label: context.translate(LanguageLabelKeys.callUs),
            onTap: callSupport,
          ),
        ),
        if (whatsAppText != null)
          Expanded(
            child: _ContactButton(
              icon: Icons.chat_outlined,
              label: context.translate(LanguageLabelKeys.whatsappUs),
              onTap: () => whatsAppSupport(whatsAppText!),
            ),
          ),
      ],
    );
  }
}

/// A small "Call us" pill for an app bar (support chat).
class CallSupportPill extends StatelessWidget {
  const CallSupportPill({super.key});

  @override
  Widget build(BuildContext context) {
    if (currentSupportNumber().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: ThemeConstants.paddingM),
      child: _ContactButton(
        icon: Icons.call_outlined,
        label: context.translate(LanguageLabelKeys.callUs),
        onTap: callSupport,
        compact: true,
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.r10,
        onTap: onTap,
        child: Container(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: compact
                ? ThemeConstants.paddingM
                : ThemeConstants.paddingL,
            vertical: compact
                ? ThemeConstants.paddingXS
                : ThemeConstants.paddingM,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.r10,
            border: Border.all(color: context.cs.primary),
          ),
          child: Row(
            mainAxisSize: .min,
            mainAxisAlignment: .center,
            spacing: ThemeConstants.spaceS,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: context.cs.primary),
              Flexible(
                child: AppText(
                  label,
                  style: context.tt.labelLarge?.copyWith(
                    color: context.cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
