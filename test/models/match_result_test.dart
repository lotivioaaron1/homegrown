// test/models/match_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/match_result.dart';

void main() {
  group('MatchResult', () {
    test('toMap includes every field needed to rebuild the match', () {
      const match = MatchResult(
        id: 'm1',
        eventId: 'e1',
        sport: 'Basketball',
        sideA: ['a1', 'a2'],
        sideB: ['b1', 'b2'],
        scoreA: 78,
        scoreB: 65,
        winner: 'A',
        status: 'pending',
        recordedBy: 'coach1',
      );

      final map = match.toMap();

      expect(map['eventId'], 'e1');
      expect(map['sport'], 'Basketball');
      expect(map['sideA'], ['a1', 'a2']);
      expect(map['sideB'], ['b1', 'b2']);
      expect(map['scoreA'], 78);
      expect(map['scoreB'], 65);
      expect(map['winner'], 'A');
      expect(map['status'], 'pending');
      expect(map['recordedBy'], 'coach1');
    });

    test('fromMap round-trips the id and fields written by toMap', () {
      final rebuilt = MatchResult.fromMap('m1', {
        'eventId': 'e1',
        'sport': 'Basketball',
        'sideA': ['a1', 'a2'],
        'sideB': ['b1', 'b2'],
        'scoreA': 78,
        'scoreB': 65,
        'winner': 'A',
        'status': 'finalized',
        'recordedBy': 'coach1',
      });

      expect(rebuilt.id, 'm1');
      expect(rebuilt.sideA, ['a1', 'a2']);
      expect(rebuilt.status, 'finalized');
      expect(rebuilt.isFinalized, isTrue);
    });
  });
}
