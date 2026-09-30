// test/utils/draft_publish_test.dart
//
// Publishing a saved draft: when it may go live, and who hears about it.
// A draft is the one event nobody has been told about yet, so the
// notification audience is the part most worth pinning down.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/draft_publish.dart';

// A fixed "now" so the tests never depend on the wall clock.
final _now = DateTime(2026, 6, 15, 12, 0);

List<Map<String, dynamic>> _side(String team, int count) => [
      for (var i = 0; i < count; i++)
        {'uid': '$team$i', 'fullName': 'Player $team$i', 'team': team},
    ];

Map<String, dynamic> _draft({
  DateTime? date,
  bool noDate = false,
  String sport = 'Badminton',
  int countA = 1,
  int countB = 1,
  String? coachA = 'coachA',
  String? coachB = 'coachB',
}) =>
    {
      'name': 'Barangay Cup',
      'status': 'draft',
      'sport': sport,
      'venue': 'Albay Astrodome',
      if (!noDate)
        'eventDate':
            Timestamp.fromDate(date ?? _now.add(const Duration(days: 7))),
      'teamAName': 'Bicol Hawks',
      'teamBName': 'Mayon Blazers',
      'teamACoachId': coachA,
      'teamBCoachId': coachB,
      'players': [..._side('A', countA), ..._side('B', countB)],
    };

void main() {
  group('draftPublishProblem', () {
    test('a dated draft with both teams ready can be published', () {
      expect(draftPublishProblem(_draft(), now: _now), isNull);
    });

    test('an undated draft asks for a date', () {
      expect(draftPublishProblem(_draft(noDate: true), now: _now),
          contains('Set a date'));
    });

    test('a draft whose date has passed asks for a new one', () {
      final stale = _draft(date: _now.subtract(const Duration(hours: 1)));
      expect(draftPublishProblem(stale, now: _now), contains('already passed'));
    });

    test('a side with no team picked is reported', () {
      expect(draftPublishProblem(_draft(coachB: null), now: _now),
          'Pick Team B before continuing.');
    });

    test('a side below the sport minimum is reported by team name', () {
      final short = _draft(sport: 'Basketball', countA: 5, countB: 3);
      expect(draftPublishProblem(short, now: _now),
          'Mayon Blazers has only 3 players. Basketball needs at least 5 per side.');
    });
  });

  group('publishNotices', () {
    test('players and coaches each get their own wording', () {
      final notices = publishNotices(_draft());
      final player = notices.firstWhere((n) => n.uid == 'A0');
      final coach = notices.firstWhere((n) => n.uid == 'coachB');

      expect(player.title, "You're in an upcoming game");
      expect(player.body,
          'Added to Barangay Cup on Jun 22, 2026 at Albay Astrodome');
      expect(coach.title, 'Your team has an upcoming game');
      expect(coach.body,
          'Mayon Blazers plays in Barangay Cup on Jun 22, 2026 '
          'at Albay Astrodome');
    });

    test('reaches every player and both coaches', () {
      final uids = publishNotices(_draft(countA: 2, countB: 2))
          .map((n) => n.uid)
          .toList();
      expect(uids, unorderedEquals(['A0', 'A1', 'B0', 'B1', 'coachA', 'coachB']));
    });

    test('a coach picked for both sides is notified once', () {
      final uids = publishNotices(_draft(coachA: 'same', coachB: 'same'))
          .where((n) => n.uid == 'same');
      expect(uids, hasLength(1));
    });

    test('a missing or empty coach id is skipped', () {
      final uids =
          publishNotices(_draft(coachA: '', coachB: null)).map((n) => n.uid);
      expect(uids, unorderedEquals(['A0', 'B0']));
    });

    test('an undated event leaves the date out of the message', () {
      final player =
          publishNotices(_draft(noDate: true)).firstWhere((n) => n.uid == 'A0');
      expect(player.body, 'Added to Barangay Cup at Albay Astrodome');
    });
  });
}
