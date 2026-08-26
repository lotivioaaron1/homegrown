// test/services/barangay_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

      final names = await BarangayService.fetchBarangays(client: client);

      expect(names, [
        "Bgy. 47 - Arimbay",
        "Bgy. 1 - Em's Barrio (Pob.)",
        "Bgy. 24 - Rizal Street",
      ]);
    });

    test('caches the result so a second call does not hit the network',
        () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('[{"code": "050506001", "name": "Bgy. 47 - Arimbay"}]', 200);
      });

      await BarangayService.fetchBarangays(client: client);
      await BarangayService.fetchBarangays(client: client);

      expect(requestCount, 1);
    });

    test('throws BarangayException on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      expect(
        () => BarangayService.fetchBarangays(client: client),
        throwsA(isA<BarangayException>()),
      );
    });
  });
}
