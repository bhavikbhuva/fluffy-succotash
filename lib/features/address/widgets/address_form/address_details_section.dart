import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

/// PestRaksh: an Indian PIN code is 6 digits and never starts with 0 (the
/// backend checks the same).
bool isValidIndianPincode(String value) =>
    RegExp(r'^[1-9][0-9]{5}$').hasMatch(value.trim());

/// Address, landmark, area and city/pincode/state/country fields.
class AddressDetailsSection extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController pincodeCtrl;

  /// State selector — either the [RegionDropdownField] (country has regions)
  /// or the free-text manual fallback, built by the parent so it can switch
  /// between the two based on the regions api response.
  final Widget stateField;

  /// Country selector — the [CountryDropdownField], built by the parent so
  /// selecting a country can drive the region fetch.
  final Widget countryField;

  /// Snapshotted once by the parent at init — whether these fields already
  /// had a value (from the saved address / map geocode) before the user
  /// touched anything. Deciding this from live controller text instead would
  /// re-lock a field the moment the user finishes typing into it.
  final bool cityPrefilled;
  final bool pincodePrefilled;

  /// PestRaksh: the service zone's "city, state, country" line, when the zone
  /// under the pin has full details. Then it's shown read-only instead of the
  /// City field and the Country and State dropdowns.
  final TextEditingController? zoneLocationCtrl;

  /// PestRaksh: in India the PIN code is at most 6 digits and checked on save.
  final bool pincodeIsIndian;

  const AddressDetailsSection({
    super.key,
    required this.addressCtrl,
    required this.landmarkCtrl,
    required this.areaCtrl,
    required this.cityCtrl,
    required this.pincodeCtrl,
    required this.stateField,
    required this.countryField,
    required this.cityPrefilled,
    required this.pincodePrefilled,
    this.zoneLocationCtrl,
    this.pincodeIsIndian = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fields already filled from the map pick are hidden entirely — only
    // fields missing from the geocoding result stay open for manual entry.
    final showCity = !cityPrefilled && zoneLocationCtrl == null;
    final showPincode = !pincodePrefilled;

    final cityField = AppTextField(
      controller: cityCtrl,
      isRequired: true,
      labelText: context.translate(LanguageLabelKeys.city),
      hintText: context.translate(LanguageLabelKeys.enterCity),
      textCapitalization: TextCapitalization.words,
      validator: (v) => (v == null || v.trim().isEmpty)
          ? context.translate(LanguageLabelKeys.required)
          : null,
    );

    final pincodeField = AppTextField(
      controller: pincodeCtrl,
      isRequired: true,
      labelText: context.translate(LanguageLabelKeys.pincode),
      hintText: context.translate(LanguageLabelKeys.enterPincode),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // PestRaksh: an Indian PIN code has 6 digits.
        if (pincodeIsIndian) LengthLimitingTextInputFormatter(6),
      ],
      validator: (v) {
        // PestRaksh: required, and in India 6 digits not starting with 0.
        final pincode = (v ?? '').replaceAll(RegExp(r'\s+'), '');
        if (pincode.isEmpty) {
          return context.translate(LanguageLabelKeys.required);
        }
        if (pincodeIsIndian && !isValidIndianPincode(pincode)) {
          return context.translate(LanguageLabelKeys.invalidPincode);
        }
        return null;
      },
    );

    return Column(
      spacing: ThemeConstants.spaceL,
      children: [
        AppTextField(
          controller: addressCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.address),
          hintText: context.translate(LanguageLabelKeys.enterFullAddress),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.addressRequired)
              : null,
        ),
        AppTextField(
          controller: landmarkCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.landmark),
          hintText: context.translate(LanguageLabelKeys.nearbyLandmark),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.landmarkRequired)
              : null,
        ),
        AppTextField(
          controller: areaCtrl,
          isRequired: true,
          labelText: context.translate(LanguageLabelKeys.areaLocality),
          hintText: context.translate(LanguageLabelKeys.enterAreaOrLocality),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? context.translate(LanguageLabelKeys.areaRequired)
              : null,
        ),
        if (showCity || showPincode)
          Row(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              if (showCity) Expanded(child: cityField),
              if (showPincode) Expanded(child: pincodeField),
            ],
          ),
        // PestRaksh: city, state and country from the service zone, as one
        // read-only line; the dropdowns only when the zone's details are
        // incomplete.
        if (zoneLocationCtrl != null)
          AppTextField(
            controller: zoneLocationCtrl!,
            readOnly: true,
            maxLines: null,
            labelText: context.translate(LanguageLabelKeys.cityStateCountry),
          )
        else
          Row(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceM,
            children: [
              Expanded(child: countryField),
              Expanded(child: stateField),
            ],
          ),
      ],
    );
  }
}
