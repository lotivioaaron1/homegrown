// test/services/directions_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/services/directions_service.dart';

const _origin = LatLng(13.1391, 123.7438);
const _destination = LatLng(13.1500, 123.7500);

String _okBody({
  String polyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
  String distanceText = '5.2 km',
  String durationText = '12 mins',
}) =>
    '''
{
  "status": "OK",
  "routes": [{
    "overview_polyline": { "points": "$polyline" },
    "legs": [{
      "distance": { "text": "$distanceText", "value": 5200 },
      "duration": { "text": "$durationText", "value": 720 }
    }]
  }]
}
''';

void main() {
  group('DirectionsService.fetchDrivingRoute', () {
    test('builds request URL with origin, destination, mode, and API key as query params', () async {
      Uri? capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(_okBody(), 200);
      });

      await DirectionsService.fetchDrivingRoute(
        origin: _origin,
        destination: _destination,
        client: client,
      );

      expect(capturedUrl, isNotNull);
      expect(capturedUrl!.queryParameters['origin'], '13.1391,123.7438');
      expect(capturedUrl!.queryParameters['destination'], '13.15,123.75');
      expect(capturedUrl!.queryParameters['mode'], 'driving');
      expect(capturedUrl!.queryParameters['key'], isNotEmpty);
    });

    test('parses distance and duration text from a successful OK response', () async {
      final client = MockClient((request) async => http.Response(
          _okBody(distanceText: '8.1 km', durationText: '20 mins'), 200));

      final result = await DirectionsService.fetchDrivingRoute(
        origin: _origin,
        destination: _destination,
        client: client,
      );

      expect(result.distanceText, '8.1 km');
      expect(result.durationText, '20 mins');
    });

    test('decodes the overview polyline into the correct list of LatLng points', () async {
      final client = MockClient((request) async => http.Response(_okBody(), 200));

      final result = await DirectionsService.fetchDrivingRoute(
        origin: _origin,
        destination: _destination,
        client: client,
      );

      expect(result.points.length, 3);
      expect(result.points[0].latitude, closeTo(38.5, 0.0001));
      expect(result.points[0].longitude, closeTo(-120.2, 0.0001));
      expect(result.points[1].latitude, closeTo(40.7, 0.0001));
      expect(result.points[1].longitude, closeTo(-120.95, 0.0001));
      expect(result.points[2].latitude, closeTo(43.252, 0.0001));
      expect(result.points[2].longitude, closeTo(-126.453, 0.0001));
    });

    test('throws DirectionsException when status is ZERO_RESULTS', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "ZERO_RESULTS", "routes": []}', 200));

      expect(
        () => DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client),
        throwsA(isA<DirectionsException>()),
      );
    });

    test('throws DirectionsException when routes is empty despite OK status', () async {
      final client = MockClient(
          (request) async => http.Response('{"status": "OK", "routes": []}', 200));

      expect(
        () => DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client),
        throwsA(isA<DirectionsException>()),
      );
    });

    test('throws DirectionsException on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      expect(
        () => DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client),
        throwsA(isA<DirectionsException>()),
      );
    });

    test('gives a "no route" message (not a connectivity message) when status is ZERO_RESULTS', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "ZERO_RESULTS", "routes": []}', 200));

      try {
        await DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client);
        fail('expected DirectionsException');
      } on DirectionsException catch (e) {
        expect(e.message, 'No driving route found to this venue.');
      }
    });

    test('gives a denial-specific message when status is REQUEST_DENIED', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "REQUEST_DENIED", "routes": []}', 200));

      try {
        await DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client);
        fail('expected DirectionsException');
      } on DirectionsException catch (e) {
        expect(e.message, 'Directions request was denied. Please contact support.');
      }
    });

    test('gives a busy-service message when status is OVER_QUERY_LIMIT', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "OVER_QUERY_LIMIT", "routes": []}', 200));

      try {
        await DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client);
        fail('expected DirectionsException');
      } on DirectionsException catch (e) {
        expect(e.message, 'Directions service is busy. Please try again shortly.');
      }
    });

    test('gives a server-unavailable message (not a "no route" message) on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 503));

      try {
        await DirectionsService.fetchDrivingRoute(
            origin: _origin, destination: _destination, client: client);
        fail('expected DirectionsException');
      } on DirectionsException catch (e) {
        expect(e.message, 'Directions service unavailable (HTTP 503). Please try again later.');
      }
    });
  });
}
