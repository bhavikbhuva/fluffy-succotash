// PestRaksh: "use current location" in the address picker starts on the city
// when the phone is far away, as the website does (services-frontend
// `NewAddressModal.tsx`): someone booking for a Bangalore home from elsewhere
// then starts in Bangalore, not on a pin we can't serve.
import 'dart:math' as math;

import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/utils/geo_polygon.dart';
import 'package:latlong2/latlong.dart';

/// Further than this from the city centre, the map starts on the centre.
const double farFromCityKm = 80;

/// Great-circle distance between [a] and [b] in kilometres (haversine).
double distanceKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Where the map should start for the phone's [position]: [cityCentre] when
/// the phone is more than [farFromCityKm] from it, otherwise [position].
/// Without a centre, always [position].
LatLng startPointNearCity(LatLng position, LatLng? cityCentre) {
  if (cityCentre == null) return position;
  return distanceKm(position, cityCentre) > farFromCityKm
      ? cityCentre
      : position;
}

/// The middle of the customer's zone: the zone with [zoneId], or the only
/// zone when there is just one. Null when neither is found or the zone has
/// no usable boundary.
LatLng? zoneCentre(List<ZonesData> zones, int? zoneId) {
  final zone =
      zones.where((z) => zoneId != null && z.id == zoneId).firstOrNull ??
      (zones.length == 1 ? zones.first : null);
  final boundary = (zone?.polygonBoundary ?? [])
      .where((p) => p.lat != null && p.lng != null)
      .map((p) => LatLng(p.lat!, p.lng!))
      .toList();
  return boundary.length >= 3 ? polygonCentroid(boundary) : null;
}
