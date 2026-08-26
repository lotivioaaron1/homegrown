// test/services/barangay_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/constants/legazpi_barangays_fallback.dart';
import 'package:homegrown/services/barangay_service.dart';

void main() {
  group('BarangayService.fetchBarangays', () {
    setUp(() => BarangayService.resetCache());

    test('parses barangay names sorted by name rather than zone number',
        () async {
      final client = MockClient((request) async => http.Response('''
      [
        {"code": "050506001", "name": "Bgy. 47 - Arimbay"},
        {"code": "050506005", "name": "Bgy. 1 - Em's Barrio (Pob.)"},
        {"code": "050506073", "name": "Bgy. 24 - Rizal Street"}
      ]
      ''', 200));

      final result = await BarangayService.fetchBarangays(client: client);

      expect(result.names, [
        "Bgy. 47 - Arimbay",
        "Bgy. 1 - Em's Barrio (Pob.)",
        "Bgy. 24 - Rizal Street",
      ]);
      expect(result.isOffline, isFalse);
    });

    test('caches a live result so a second call does not hit the network',
        () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response(
            '[{"code": "050506001", "name": "Bgy. 47 - Arimbay"}]', 200);
      });

      await BarangayService.fetchBarangays(client: client);
      await BarangayService.fetchBarangays(client: client);

      expect(requestCount, 1);
    });

    test('falls back to the bundled snapshot on a non-200 response', () async {
      final client =
          MockClient((request) async => http.Response('Server error', 500));

      final result = await BarangayService.fetchBarangays(client: client);

      expect(result.isOffline, isTrue);
      expect(result.names, hasLength(kLegazpiBarangaysFallback.length));
      expect(result.names, contains('Bgy. 47 - Arimbay'));
    });

    test('falls back to the bundled snapshot when the request throws',
        () async {
      final client = MockClient((request) async => throw http.ClientException(
          'Failed host lookup: psgc.gitlab.io'));

      final result = await BarangayService.fetchBarangays(client: client);

      expect(result.isOffline, isTrue);
      expect(result.names, hasLength(kLegazpiBarangaysFallback.length));
    });

    test('falls back when the registry returns an empty list', () async {
      final client = MockClient((request) async => http.Response('[]', 200));

      final result = await BarangayService.fetchBarangays(client: client);

      expect(result.isOffline, isTrue);
      expect(result.names, isNotEmpty);
    });

    // Registration depends on this list, so an offline answer must not become
    // sticky for the rest of the process — the next attempt has to try the
    // live registry again.
    test('retries the network after an offline result', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) return http.Response('Server error', 500);
        return http.Response(
            '[{"code": "050506001", "name": "Bgy. 47 - Arimbay"}]', 200);
      });

      final offline = await BarangayService.fetchBarangays(client: client);
      final live = await BarangayService.fetchBarangays(client: client);

      expect(offline.isOffline, isTrue);
      expect(live.isOffline, isFalse);
      expect(live.names, ['Bgy. 47 - Arimbay']);
      expect(requestCount, 2);
    });

    test('the bundled snapshot is sorted the same way as live data', () async {
      final client =
          MockClient((request) async => http.Response('Server error', 500));

      final result = await BarangayService.fetchBarangays(client: client);
      final sortKeys = result.names
          .map((n) => n.split(' - ').skip(1).join(' - '))
          .toList();

      expect(sortKeys, orderedEquals(List<String>.of(sortKeys)..sort()));
    });
  });
}
