// test/utils/event_recipients_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_recipients.dart';

void main() {
  group('eventAudienceUids', () {
    test('includes the roster and both head coaches', () {
      final result = eventAudienceUids({
        'playerUids': ['a1', 'a2'],
        'teamACoachId': 'coachA',
        'teamBCoachId': 'coachB',
      });
      expect(result, containsAll(['a1', 'a2', 'coachA', 'coachB']));
      expect(result, hasLength(4));
    });

    test('notifies a coach fielding both sides only once', () {
      final result = eventAudienceUids({
        'playerUids': ['a1'],
        'teamACoachId': 'coach',
        'teamBCoachId': 'coach',
      });
      expect(result, ['a1', 'coach']);
    });

    test('skips a side that has no team picked yet', () {
      final result = eventAudienceUids({
        'playerUids': ['a1'],
        'teamACoachId': 'coachA',
        'teamBCoachId': null,
      });
      expect(result, ['a1', 'coachA']);
    });

    test('ignores empty-string coach ids', () {
      expect(eventAudienceUids({'playerUids': <String>[], 'teamACoachId': ''}),
          isEmpty);
    });

    test('handles an event doc missing every field', () {
      // Tournament-scheduled and older events are not guaranteed to carry
      // these keys, and the cancel path feeds this straight from Firestore.
      expect(eventAudienceUids({}), isEmpty);
    });

    test('does not duplicate a coach who is also on the roster', () {
      final result = eventAudienceUids({
        'playerUids': ['coachA', 'a1'],
        'teamACoachId': 'coachA',
      });
      expect(result, ['coachA', 'a1']);
    });
  });
}
