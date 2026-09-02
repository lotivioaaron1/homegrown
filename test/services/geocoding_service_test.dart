// test/services/geocoding_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/services/geocoding_service.dart';

const _point = LatLng(13.144195, 123.746363);

void main() {
  // Every test here reverse-geocodes the same point with a different mock
  // response, so the process-wide address cache has to be reset between them.
  setUp(GeocodingService.clearCache);

  group('GeocodingService.reverseGeocode', () {
    test('sends the tapped point as the latlng query param', () async {
      Uri? capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        return http.Response('{"status": "OK", "results": []}', 200);
      });

      await GeocodingService.reverseGeocode(_point, client: client);

      expect(capturedUrl!.queryParameters['latlng'], '13.144195,123.746363');
    });

    test('returns the formatted address from a successful OK response', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "OK", "results": [{"formatted_address": "Legazpi Port District, Legazpi City, Albay"}]}',
          200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, 'Legazpi Port District, Legazpi City, Albay');
    });

    test('returns null when status is not OK', () async {
      final client = MockClient((request) async =>
          http.Response('{"status": "ZERO_RESULTS", "results": []}', 200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });

    test('returns null when results is empty despite OK status', () async {
      final client = MockClient(
          (request) async => http.Response('{"status": "OK", "results": []}', 200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });
  });

  group('GeocodingService caching', () {
    const okBody =
        '{"status": "OK", "results": [{"formatted_address": "Legazpi Port District"}]}';

    test('serves a repeated point from cache without a second request', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(okBody, 200);
      });

      await GeocodingService.reverseGeocode(_point, client: client);
      final second = await GeocodingService.reverseGeocode(_point, client: client);

      expect(requestCount, 1);
      expect(second, 'Legazpi Port District');
    });

    test('treats points within ~11m of each other as the same tap', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(okBody, 200);
      });

      await GeocodingService.reverseGeocode(_point, client: client);
      // Differs only in the 5th decimal place — finer than a fingertip.
      await GeocodingService.reverseGeocode(
          const LatLng(13.144192, 123.746361), client: client);

      expect(requestCount, 1);
    });

    test('treats a meaningfully different point as a separate request', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(okBody, 200);
      });

      await GeocodingService.reverseGeocode(_point, client: client);
      await GeocodingService.reverseGeocode(
          const LatLng(13.1500, 123.7500), client: client);

      expect(requestCount, 2);
    });

    test('does not cache a failed lookup', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('Server error', 500);
      });

      await GeocodingService.reverseGeocode(_point, client: client);
      await GeocodingService.reverseGeocode(_point, client: client);

      expect(requestCount, 2,
          reason: 'a transient failure must not stand in for the real address');
    });
  });
}
