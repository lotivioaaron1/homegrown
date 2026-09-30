// test/utils/championships_test.dart
//
// Who a tournament title belongs to, and which titles each showcase lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/bracket_slot.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/championships.dart';
import 'package:homegrown/utils/tournament_notices.dart';

Tournament _cup(
  String id, {
  String status = Tournament.statusCompleted,
  String? champion = 'coachA',
  DateTime? completedAt,
  String organizer = 'org',
}) =>
    Tournament(
      id: id,
      organizerId: organizer,
      name: 'Cup $id',
      sport: 'Basketball',
      status: status,
      championCoachId: status == Tournament.statusCompleted ? champion : null,
      championTeamName: 'Rawis Rockets',
      completedAt: completedAt ?? DateTime(2026, 9, 29),
      entrants: const [
        TournamentEntrant(
          seed: 1,
          coachId: 'coachA',
          teamName: 'Rawis Rockets',
          players: [
            EntrantPlayer(uid: 'a1', fullName: 'A One'),
            EntrantPlayer(uid: 'a2', fullName: 'A Two'),
          ],
        ),
        TournamentEntrant(
          seed: 2,
          coachId: 'coachB',
          teamName: 'Bitano Bulls',
          players: [EntrantPlayer(uid: 'b1', fullName: 'B One')],
        ),
      ],
    );

List<String> _ids(List<Tournament> ts) => ts.map((t) => t.id).toList();

void main() {
  group('isChampion', () {
    test('credits the champion coach', () {
      expect(isChampion(_cup('1'), 'coachA'), isTrue);
    });

    test("credits every player on the champion's entered roster", () {
      expect(isChampion(_cup('1'), 'a1'), isTrue);
      expect(isChampion(_cup('1'), 'a2'), isTrue);
    });

    test('does not credit the runner-up or its coach', () {
      expect(isChampion(_cup('1'), 'b1'), isFalse);
      expect(isChampion(_cup('1'), 'coachB'), isFalse);
    });

    test('credits nobody before the final is played', () {
      final running = _cup('1', status: Tournament.statusActive);

      expect(isChampion(running, 'coachA'), isFalse);
      expect(isChampion(running, 'a1'), isFalse);
    });

    test('credits nobody for a blank id', () {
      expect(isChampion(_cup('1'), ''), isFalse);
    });
  });

  group('titlesFor', () {
    test('lists only the titles someone won, newest first', () {
      final titles = titlesFor([
        _cup('old', completedAt: DateTime(2026, 5, 1)),
        _cup('lost', champion: 'coachB'),
        _cup('new', completedAt: DateTime(2026, 9, 29)),
      ], 'a1');

      expect(_ids(titles), ['new', 'old']);
    });
  });

  group('teamTitles', () {
    test("lists the titles a coach's team won", () {
      final titles = teamTitles([
        _cup('won'),
        _cup('lost', champion: 'coachB'),
        _cup('running', status: Tournament.statusActive),
      ], 'coachA');

      expect(_ids(titles), ['won']);
    });
  });

  group('recentChampions', () {
    final now = DateTime(2026, 9, 30, 12);

    test('keeps titles won in the last week, newest first', () {
      final recent = recentChampions([
        _cup('two days', completedAt: DateTime(2026, 9, 28)),
        _cup('yesterday', completedAt: DateTime(2026, 9, 29)),
        _cup('last month', completedAt: DateTime(2026, 8, 30)),
      ], now: now);

      expect(_ids(recent), ['yesterday', 'two days']);
    });

    test('drops a tournament still being played', () {
      final recent = recentChampions(
          [_cup('running', status: Tournament.statusActive)],
          now: now);

      expect(recent, isEmpty);
    });

    test("leaves out the given organizer's own tournaments", () {
      final recent = recentChampions([
        _cup('mine'),
        _cup('theirs', organizer: 'otherOrg'),
      ], now: now, exceptOrganizer: 'org');

      expect(_ids(recent), ['theirs']);
    });
  });

  group('titleCountLabel', () {
    test('says Champion once, then counts', () {
      expect(titleCountLabel(1), 'Champion');
      expect(titleCountLabel(3), '3× Champion');
    });
  });

  group('finalStandings', () {
    SlotEntrant team(String name) =>
        SlotEntrant(seed: 1, coachId: name, teamName: name);

    // A game between [a] and [b]; [winner] null means not played yet.
    BracketSlot game(String id, int round, int slot, String a, String b,
            {String? winner, String? nextSide, bool third = false}) =>
        BracketSlot(
          id: id,
          organizerId: 'org',
          round: round,
          slot: slot,
          isThirdPlace: third,
          entrantA: team(a),
          entrantB: team(b),
          nextSlotSide: nextSide,
          status: winner == null
              ? BracketSlot.statusReady
              : BracketSlot.statusCompleted,
          winnerCoachId: winner,
        );

    const eight = Tournament(
        id: 't', organizerId: 'org', name: 'Cup', sport: 'Basketball',
        roundCount: 3);

    final semis = [
      game('r2m1', 2, 1, 'Rockets', 'Tigers', winner: 'Rockets', nextSide: 'A'),
      game('r2m2', 2, 2, 'Bulls', 'Titans', winner: 'Bulls', nextSide: 'B'),
    ];
    final finalPlayed =
        game('r3m1', 3, 1, 'Rockets', 'Bulls', winner: 'Rockets');

    List<(String, String)> rows(List<Standing> s) =>
        s.map((x) => (x.label, x.teamName)).toList();

    test('ranks all four once the final and battle for third are played', () {
      final standings = finalStandings(eight, [
        ...semis,
        finalPlayed,
        game('r3m2', 3, 2, 'Tigers', 'Titans', winner: 'Titans', third: true),
      ]);

      expect(rows(standings), [
        ('Champion', 'Rockets'),
        ('1st runner-up', 'Bulls'),
        ('2nd runner-up', 'Titans'),
        ('3rd runner-up', 'Tigers'),
      ]);
      expect(standings.map((s) => s.place), [1, 2, 3, 4]);
    });

    test('shares 2nd runner-up between the semifinal losers without a battle',
        () {
      final standings = finalStandings(eight, [...semis, finalPlayed]);

      expect(rows(standings), [
        ('Champion', 'Rockets'),
        ('1st runner-up', 'Bulls'),
        ('Joint 2nd runner-up', 'Tigers'),
        ('Joint 2nd runner-up', 'Titans'),
      ]);
      expect(standings.where((s) => s.joint).length, 2);
    });

    test('shares it too while the battle for third is still to be played', () {
      final standings = finalStandings(eight, [
        ...semis,
        finalPlayed,
        game('r3m2', 3, 2, 'Tigers', 'Titans', third: true),
      ]);

      expect(standings.skip(2).map((s) => s.label),
          ['Joint 2nd runner-up', 'Joint 2nd runner-up']);
    });

    // Four teams: the semifinals are the opening round.
    test('reads the semifinals from round 1 in a four-team bracket', () {
      const four = Tournament(
          id: 't', organizerId: 'org', name: 'Cup', sport: 'Basketball',
          roundCount: 2);
      final standings = finalStandings(four, [
        game('r1m1', 1, 1, 'Rockets', 'Tigers', winner: 'Rockets', nextSide: 'A'),
        game('r1m2', 1, 2, 'Bulls', 'Titans', winner: 'Bulls', nextSide: 'B'),
        game('r2m1', 2, 1, 'Rockets', 'Bulls', winner: 'Bulls'),
        game('r2m2', 2, 2, 'Tigers', 'Titans', winner: 'Tigers', third: true),
      ]);

      expect(rows(standings), [
        ('Champion', 'Bulls'),
        ('1st runner-up', 'Rockets'),
        ('2nd runner-up', 'Tigers'),
        ('3rd runner-up', 'Titans'),
      ]);
    });
  });

  group('champion averages', () {
    const rockets = SlotEntrant(seed: 1, coachId: 'coachA', teamName: 'Rockets');
    const bulls = SlotEntrant(seed: 2, coachId: 'coachB', teamName: 'Bulls');
    const tigers = SlotEntrant(seed: 3, coachId: 'coachC', teamName: 'Tigers');

    BracketSlot game(String id, SlotEntrant a, SlotEntrant? b,
            {String? winner, String? matchId}) =>
        BracketSlot(
          id: id,
          organizerId: 'org',
          round: 1,
          slot: 1,
          entrantA: a,
          entrantB: b,
          status: winner == null
              ? BracketSlot.statusReady
              : BracketSlot.statusCompleted,
          winnerCoachId: winner,
          matchId: matchId,
        );

    final slots = [
      game('r1m1', rockets, tigers, winner: 'coachA', matchId: 'm1'),
      game('r2m1', rockets, bulls, winner: 'coachA', matchId: 'm2'),
      game('r1m2', bulls, tigers, winner: 'coachB', matchId: 'm3'),
    ];

    Map<String, dynamic> line(String matchId, String athleteId,
            Map<String, dynamic> stats) =>
        {'matchId': matchId, 'athleteId': athleteId, 'stats': stats};

    group('matchIdsFor', () {
      test("lists only the team's played games", () {
        expect(
            matchIdsFor('coachA', [
              ...slots,
              game('bye', rockets, null, winner: 'coachA'),
              game('next', rockets, bulls),
            ]),
            ['m1', 'm2']);
      });
    });

    test('adds up each game, then averages the games', () {
      final a = championAverages(_cup('1'), slots, [
        line('m1', 'a1', {'points': 20, 'rebounds': 4}),
        line('m1', 'a2', {'points': 10, 'rebounds': 6}),
        line('m2', 'a1', {'points': 16, 'rebounds': 3}),
        line('m2', 'a2', {'points': 8, 'rebounds': 5}),
      ])!;

      expect(a.averages['Points'], 27);
      expect(a.averages['Rebounds'], 9);
      expect(a.games, 2);
      expect(a.gamesPlayed, 2);
    });

    test("leaves out the opponents and games the champion didn't play", () {
      final a = championAverages(_cup('1'), slots, [
        line('m1', 'a1', {'points': 30}),
        line('m1', 'b1', {'points': 99}),
        line('m3', 'a1', {'points': 99}),
      ])!;

      expect(a.averages['Points'], 30);
    });

    test('averages only the games with stats, and says how many there were',
        () {
      final a = championAverages(_cup('1'), slots, [
        line('m1', 'a1', {'points': 30}),
      ])!;

      expect(a.averages['Points'], 30);
      expect(a.games, 1);
      expect(a.gamesPlayed, 2);
    });

    test('counts a line saved twice for one player once', () {
      final a = championAverages(_cup('1'), slots, [
        line('m1', 'a1', {'points': 30}),
        line('m1', 'a1', {'points': 30}),
      ])!;

      expect(a.averages['Points'], 30);
    });

    test("takes a badminton side's sets once, not once per partner", () {
      const doubles = Tournament(
        id: 't',
        organizerId: 'org',
        name: 'Open',
        sport: 'Badminton',
        status: Tournament.statusCompleted,
        championCoachId: 'coachA',
        entrants: [
          TournamentEntrant(seed: 1, coachId: 'coachA', teamName: 'Rockets',
              players: [
                EntrantPlayer(uid: 'a1', fullName: 'A One'),
                EntrantPlayer(uid: 'a2', fullName: 'A Two'),
              ]),
        ],
      );
      final a = championAverages(doubles, slots, [
        line('m1', 'a1', {'pointsScored': 20, 'setsWon': 2, 'matchWon': true}),
        line('m1', 'a2', {'pointsScored': 22, 'setsWon': 2, 'matchWon': true}),
      ])!;

      expect(a.averages['Sets Won'], 2);
      expect(a.averages['Points Scored'], 42);
      expect(a.averages['Win Rate %'], 100);
    });

    test('is null without any stats', () {
      expect(championAverages(_cup('1'), slots, const []), isNull);
    });

    test('is null before a champion is crowned', () {
      expect(
          championAverages(_cup('1', status: Tournament.statusActive), slots, [
            line('m1', 'a1', {'points': 30}),
          ]),
          isNull);
    });
  });

  group('isChampionNotice', () {
    test('recognises the champion notification the app sends', () {
      final notices = resultNotices(
        tournamentName: 'Mayon Cup',
        round: 3,
        roundCount: 3,
        winnerTeam: 'Rawis Rockets',
        loserTeam: 'Bitano Bulls',
        winnerScore: 84,
        loserScore: 70,
      );

      expect(isChampionNotice(notices.winner.title), isTrue);
      expect(isChampionNotice(notices.loser.title), isFalse);
    });

    test('ignores a win in an earlier round', () {
      expect(isChampionNotice("Congratulations! You're in the Final"), isFalse);
    });
  });
}
