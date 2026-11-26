import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// One filter choice. [value] is the API `filter` param ('' = all).
typedef TransactionFilterOption = ({String label, String value});

/// Radio bottom sheet for the server-side `filter` param. Pops on select.
void showTransactionFilterSheet(
  BuildContext context, {
  required List<TransactionFilterOption> options,
  required String selected,
  required ValueChanged<String> onSelected,
}) {
  showAppBottomSheet(
    context,
    isScrollControlled: false,
    title: context.translate(LanguageLabelKeys.filterByType),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingXL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingXL,
      ThemeConstants.paddingXXL,
    ),
    builder: (sheetContext) => RadioGroup<String>(
      groupValue: selected,
      onChanged: (val) {
        if (val == null) return;
        AppNavigator.pop(sheetContext);
        onSelected(val);
      },
      child: SlideAnimationList(
        children: options
            .map(
              (o) => RadioListTile<String>(
                title: AppText(o.label),
                value: o.value,
                activeColor: sheetContext.cs.primary,
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: EdgeInsetsDirectional.zero,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              ),
            )
            .toList(),
      ),
    ),
  );
}
