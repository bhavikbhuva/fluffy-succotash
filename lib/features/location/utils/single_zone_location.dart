import 'dart:async';

import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/location/cubit/session_zone_cubit.dart';
import 'package:customer/utils/geo_polygon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

/// PestRaksh: saves a validated delivery point as the session location: the
/// point, the zone and the zone's channel together, then reloads the cart if
/// the channel changed. Taken out of `ZoneLocationPickerScreen` so the picker
/// and the single-zone start below store exactly the same things.
Future<void> saveSessionZoneLocation({
  required SessionZoneAvailable zoneState,
  required int? zoneId,
  required double latitude,
  required double longitude,
  required String label,
  required String address,
  required String pincode,
  required CartCubit cartCubit,
  required CartActionCubit cartActionCubit,
}) async {
  final hive = SettingsHiveBox.instance;
  final newChannel = zoneState.activeChannel ?? hive.channel;
  final channelChanged = newChannel != hive.channel;

  // Drain debounced add/remove syncs under the OLD channel before the
  // header flips — same reason as the home channel toggle.
  if (channelChanged) await cartActionCubit.flushAllPending();

  await hive.saveUserLocation(
    latitude: latitude.toString(),
    longitude: longitude.toString(),
    label: label,
    address: address,
    pincode: pincode,
  );
  await hive.saveZoneId(zoneState.zoneId ?? zoneId);
  await hive.setChannel(newChannel);

  if (channelChanged) {
    if (AuthHiveBox.instance.isLoggedIn) {
      cartCubit.resetForChannelSwitch();
      cartCubit.loadFromApi();
    } else {
      cartCubit.switchChannel(newChannel);
    }
  }
}

/// PestRaksh: with a single service zone (Bangalore) there is nothing to
/// choose, so the first-run location screen uses that zone instead of asking,
/// the same rule as the website. Picks the country the zone selector would,
/// loads its zones and, when there is exactly one, stores the zone's centre
/// as the picker would after a confirm. Returns false, having stored nothing,
/// when there are no or several zones, the centre is not deliverable, or any
/// call fails: the screen then asks as before.
Future<bool> applySingleZoneLocation(BuildContext context) async {
  final countriesCubit = context.read<CountriesCubit>();
  final cartCubit = context.read<CartCubit>();
  final cartActionCubit = context.read<CartActionCubit>();
  final repository = AddressRepository();
  try {
    final country = _defaultCountry(await _countries(countriesCubit));
    if (country?.id == null) return false;

    // PestRaksh (review): every network step has its own short time limit, so
    // a stalled connection gets the normal screen within seconds, not a
    // spinner for minutes.
    final zones =
        (await repository
                .getZones(countryId: country!.id.toString())
                .timeout(_step))
            .data ??
        const [];
    if (zones.length != 1) return false;
    final zone = zones.single;

    // The picker starts its pin on the zone's centre; with nothing stored yet
    // that is the point it would save.
    final boundary = (zone.polygonBoundary ?? [])
        .where((p) => p.lat != null && p.lng != null)
        .map((p) => LatLng(p.lat!, p.lng!))
        .toList();
    final centre = boundary.length >= 3 ? polygonCentroid(boundary) : null;
    if (centre == null) return false;

    // Same check as the picker's confirm button: only a point the Zone API
    // calls deliverable may become the session location.
    final zoneCubit = SessionZoneCubit(repository: repository);
    await zoneCubit
        .checkZone(latitude: centre.latitude, longitude: centre.longitude)
        .timeout(_step, onTimeout: () {});
    final zoneState = zoneCubit.state;
    await zoneCubit.close();
    if (zoneState is! SessionZoneAvailable) return false;

    // Address card texts, as the picker shows them: the city and the address,
    // or "Location selected" and the coordinates when the lookup fails.
    final selected = LocalizationService.instance.translate(
      LanguageLabelKeys.locationSelected,
    );
    var label = selected;
    var address =
        '${centre.latitude.toStringAsFixed(4)}, ${centre.longitude.toStringAsFixed(4)}';
    var pincode = '';
    try {
      final r = GeocodingResult.fromJson(
        await repository
            .getGeocodingByLatLng(
              latitude: centre.latitude.toString(),
              longitude: centre.longitude.toString(),
              channel: zoneState.activeChannel,
            )
            .timeout(const Duration(seconds: 5)),
      );
      label = r.city.isNotEmpty ? r.city : selected;
      address = r.formattedAddress;
      pincode = r.postalCode;
    } catch (_) {
      // Keep the fallback texts above, as the picker does.
    }

    // The zone selector remembers the country it picked.
    await SettingsHiveBox.instance.saveSelectedCountryId(country.id);
    await saveSessionZoneLocation(
      zoneState: zoneState,
      zoneId: zone.id,
      latitude: centre.latitude,
      longitude: centre.longitude,
      label: label,
      address: address,
      pincode: pincode,
      cartCubit: cartCubit,
      cartActionCubit: cartActionCubit,
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// The time limit of one network step of the single-zone start.
const _step = Duration(seconds: 8);

/// The app-wide countries list, waiting for it if it is still loading.
/// Null when it failed.
Future<List<CountriesData>?> _countries(CountriesCubit cubit) async {
  var state = cubit.state;
  if (state is CountriesInitial || state is CountriesLoading) {
    state = await cubit.stream
        .firstWhere((s) => s is CountriesLoaded || s is CountriesError)
        .timeout(_step);
  }
  return state is CountriesLoaded ? state.countries : null;
}

/// The country `CountryZoneSelector` starts on: the last one picked, else the
/// default one, else the first.
CountriesData? _defaultCountry(List<CountriesData>? countries) {
  if (countries == null || countries.isEmpty) return null;
  final lastId = SettingsHiveBox.instance.selectedCountryId;
  for (final c in countries) {
    if (lastId != null && c.id == lastId) return c;
  }
  return countries.firstWhere(
    (c) => c.isDefault == 1,
    orElse: () => countries.first,
  );
}
