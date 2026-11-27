// PestRaksh: "use current location" in the address picker starts on the city
// centre when the phone is more than 80 km away, as the website does.
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/features/address/utils/location_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _bengaluru = LatLng(12.9716, 77.5946);
const _whitefield = LatLng(12.9698, 77.7500);
const _mysuru = LatLng(12.2958, 76.6394);
const _chennai = LatLng(13.0827, 80.2707);

ZonesData _zone(int id, List<List<double>> points) => ZonesData(
  id: id,
  polygonBoundary: [
    for (final p in points) ZonePolygonPoint(lat: p[0], lng: p[1]),
  ],
);

void main() {
  group('distanceKm', () {
    test('zero for the same point', () {
      expect(distanceKm(_bengaluru, _bengaluru), 0);
    });

    test('known distances, within a kilometre or two', () {
      expect(distanceKm(_bengaluru, _whitefield), closeTo(16.8, 1));
      expect(distanceKm(_bengaluru, _mysuru), closeTo(128, 2));
      expect(distanceKm(_bengaluru, _chennai), closeTo(290, 3));
    });

    test('same either way round', () {
      expect(
        distanceKm(_mysuru, _bengaluru),
        closeTo(distanceKm(_bengaluru, _mysuru), 1e-9),
      );
    });
  });

  group('startPointNearCity', () {
    test('near the city: the phone position', () {
      expect(startPointNearCity(_whitefield, _bengaluru), _whitefield);
    });

    test('more than 80 km away: the city centre', () {
      expect(startPointNearCity(_mysuru, _bengaluru), _bengaluru);
      expect(startPointNearCity(_chennai, _bengaluru), _bengaluru);
    });

    test('just under and just over 80 km', () {
      // One degree of latitude is about 111.2 km.
      const under = LatLng(12.9716 + 0.71, 77.5946); // about 79 km
      const over = LatLng(12.9716 + 0.73, 77.5946); // about 81 km
      expect(startPointNearCity(under, _bengaluru), under);
      expect(startPointNearCity(over, _bengaluru), _bengaluru);
    });

    test('no city centre: the phone position', () {
      expect(startPointNearCity(_chennai, null), _chennai);
    });
  });

  group('zoneCentre', () {
    final square = _zone(7, [
      [12.9, 77.5],
      [12.9, 77.7],
      [13.1, 77.7],
      [13.1, 77.5],
    ]);
    final other = _zone(9, [
      [13.0, 80.2],
      [13.0, 80.3],
      [13.1, 80.3],
    ]);

    test('the middle of the zone with the stored id', () {
      final c = zoneCentre([other, square], 7)!;
      expect(c.latitude, closeTo(13.0, 1e-9));
      expect(c.longitude, closeTo(77.6, 1e-9));
    });

    test('no stored id: the only zone', () {
      final c = zoneCentre([square], null)!;
      expect(c.latitude, closeTo(13.0, 1e-9));
    });

    test('no stored id and several zones, or no zones: unknown', () {
      expect(zoneCentre([square, other], null), isNull);
      expect(zoneCentre([square, other], 42), isNull);
      expect(zoneCentre([], 7), isNull);
    });

    test('a zone without a usable boundary: unknown', () {
      expect(zoneCentre([ZonesData(id: 7)], 7), isNull);
      expect(
        zoneCentre([
          _zone(7, [
            [12.9, 77.5],
            [13.1, 77.7],
          ]),
        ], 7),
        isNull,
      );
    });
  });
}
