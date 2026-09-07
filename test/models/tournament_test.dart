import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/tournament.dart';

Tournament _sample() => const Tournament(
      id: 't1',
      organizerId: 'org-1',
      name: 'Barangay Cup 2026',
      description: 'City-wide knockout',
      sport: 'Basketball',
      status: Tournament.statusActive,
      isPublic: true,
      venue: 'Legazpi City Coliseum',
      venueAddress: 'Rizal St, Legazpi City',
      venueLat: 13.1391,
      venueLng: 123.7438,
      venueType: 'Venue',
      entrantCount: 2,
      roundCount: 1,
      entrants: [
        TournamentEntrant(
          seed: 1,
          coachId: 'coach-a',
          teamName: 'Bogtong Ballers',
          coachName: 'Coach A',
          teamLogoUrl: 'https://example.test/a.png',
          players: [
            EntrantPlayer(uid: 'p1', fullName: 'Ana Cruz', position: 'Guard'),
            EntrantPlayer(uid: 'p2', fullName: 'Ben Reyes'),
          ],
        ),
        TournamentEntrant(
          seed: 2,
          coachId: 'coach-b',
          teamName: 'Rawis Risers',
          coachName: 'Coach B',
          players: [EntrantPlayer(uid: 'p3', fullName: 'Cha Lim')],
        ),
      ],
    );

void main() {
  group('Tournament', () {
    test('survives a round trip through Firestore-shaped maps', () {
      final original = _sample();
      final restored = Tournament.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.organizerId, original.organizerId);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.sport, original.sport);
      expect(restored.status, original.status);
      expect(restored.isPublic, original.isPublic);
      expect(restored.venue, original.venue);
      expect(restored.venueLat, original.venueLat);
      expect(restored.venueLng, original.venueLng);
      expect(restored.entrantCount, original.entrantCount);
      expect(restored.roundCount, original.roundCount);
      expect(restored.hasMatchData, isFalse);
    });

    test('carries entrants and their roster snapshots through', () {
      final restored = Tournament.fromMap('t1', _sample().toMap());

      expect(restored.entrants.length, 2);
      final top = restored.entrants.first;
      expect(top.seed, 1);
      expect(top.coachId, 'coach-a');
      expect(top.teamName, 'Bogtong Ballers');
      expect(top.teamLogoUrl, 'https://example.test/a.png');
      expect(top.players.map((p) => p.uid), ['p1', 'p2']);
      expect(top.players.first.position, 'Guard');
      // A player with no position recorded round-trips as an empty string
      // rather than null, matching how an event stores its roster.
      expect(top.players.last.position, '');
    });

    test('reads back defaults from a document missing every field', () {
      final bare = Tournament.fromMap('t1', const {});

      expect(bare.status, Tournament.statusActive);
      expect(bare.isPublic, isTrue);
      expect(bare.entrants, isEmpty);
      expect(bare.championCoachId, isNull);
      expect(bare.hasMatchData, isFalse);
    });

    test('finds an entrant by the coach a bracket slot names', () {
      final t = _sample();
      expect(t.entrantFor('coach-b')?.teamName, 'Rawis Risers');
      expect(t.entrantFor('nobody'), isNull);
    });

    test('reseeding renumbers without disturbing the roster', () {
      final reseeded = _sample().entrants.first.copyWith(seed: 5);
      expect(reseeded.seed, 5);
      expect(reseeded.coachId, 'coach-a');
      expect(reseeded.players.length, 2);
    });

    test('a completed tournament reports its champion', () {
      final t = Tournament.fromMap('t1', {
        ..._sample().toMap(),
        'status': Tournament.statusCompleted,
        'championCoachId': 'coach-a',
        'championTeamName': 'Bogtong Ballers',
      });

      expect(t.isCompleted, isTrue);
      expect(t.championTeamName, 'Bogtong Ballers');
    });
  });
}
