// test/services/places_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/services/places_service.dart';

void main() {
  group('PlacesService.searchVenues', () {
    test('sends the query with Legazpi City appended and a 15km location bias around city center', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, String>? capturedHeaders;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        capturedHeaders = request.headers;
        return http.Response('{"places": []}', 200);
      });

      await PlacesService.searchVenues('Astrodome', client: client);

      expect(capturedBody!['textQuery'], 'Astrodome, Legazpi City, Albay, Philippines');
      final bias = capturedBody!['locationBias']['circle'];
      expect(bias['center']['latitude'], 13.1391);
      expect(bias['center']['longitude'], 123.7438);
      expect(bias['radius'], 15000);
      expect(capturedHeaders!['X-Goog-Api-Key'], isNotEmpty);
      expect(capturedHeaders!['X-Goog-FieldMask'], contains('places.location'));
    });

    test('parses successful results into a list of Venue', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({
        'places': [
          {
            'displayName': {'text': 'Ibalong Centrum for Recreation', 'languageCode': 'en'},
            'formattedAddress': 'Legazpi Port District, Legazpi City, Albay, Philippines',
            'location': {'latitude': 13.144195, 'longitude': 123.746363},
            'primaryType': 'stadium',
          },
        ],
      }), 200));

      final results = await PlacesService.searchVenues('ICR', client: client);

      expect(results, hasLength(1));
      expect(results.first.name, 'Ibalong Centrum for Recreation');
      expect(results.first.address, 'Legazpi Port District, Legazpi City, Albay, Philippines');
      expect(results.first.lat, 13.144195);
      expect(results.first.lng, 123.746363);
      expect(results.first.type, 'stadium');
    });

    test('returns an empty list when the response has no places key', () async {
      final client = MockClient((request) async => http.Response('{}', 200));

      final results = await PlacesService.searchVenues('a venue nobody has heard of', client: client);

      expect(results, isEmpty);
    });

    test('returns an empty list when places is an empty array', () async {
      final client = MockClient((request) async => http.Response('{"places": []}', 200));

      final results = await PlacesService.searchVenues('another obscure court', client: client);

      expect(results, isEmpty);
    });

    test('throws PlacesException on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      expect(
        () => PlacesService.searchVenues('Astrodome', client: client),
        throwsA(isA<PlacesException>()),
      );
    });

    test('falls back to "Venue" when primaryType is missing', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({
        'places': [
          {
            'displayName': {'text': 'Some Court', 'languageCode': 'en'},
            'formattedAddress': 'Legazpi City, Albay, Philippines',
            'location': {'latitude': 13.14, 'longitude': 123.74},
          },
        ],
      }), 200));

      final results = await PlacesService.searchVenues('Some Court', client: client);

      expect(results.first.type, 'Venue');
    });
  });
}
