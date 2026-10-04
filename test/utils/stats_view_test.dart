// test/utils/stats_view_test.dart
//
// What the Stats tab shows for multi-sport athletes, and which games the
// points chart draws. The chart used to take the oldest games instead of the
// most recent ones.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/stats_view.dart';

Map<String, dynamic> _game(String sport, String name) =>
    {'sport': sport, 'eventName': name};

void main() {
  group('sportsPlayed', () {
    test('lists each sport once, in the app order', () {
      final stats = [
        _game('Volleyball', 'v1'),
        _game('Basketball', 'b1'),
        _game('Volleyball', 'v2'),
      ];
      expect(sportsPlayed(stats), ['Basketball', 'Volleyball']);
    });

    test('a single-sport athlete has one entry, so no filter is offered', () {
      expect(sportsPlayed([_game('Badminton', 'a'), _game('Badminton', 'b')]),
          ['Badminton']);
    });

    test('ignores games with no sport and keeps unknown sports last', () {
      final stats = [
        {'eventName': 'no sport'},
        _game('Chess', 'c'),
        _game('Basketball', 'b'),
      ];
      expect(sportsPlayed(stats), ['Basketball', 'Chess']);
    });

    test('no games, no sports', () {
      expect(sportsPlayed(const []), isEmpty);
    });
  });

  group('filterBySport', () {
    final stats = [
      _game('Basketball', 'b2'),
      _game('Volleyball', 'v1'),
      _game('Basketball', 'b1'),
    ];

    test('null means every game', () {
      expect(filterBySport(stats, null), stats);
    });

    test('narrows to one sport and keeps the order', () {
      expect(filterBySport(stats, 'Basketball').map((g) => g['eventName']),
          ['b2', 'b1']);
    });
  });

  group('chartGames', () {
    // Newest first, the way the dashboard sorts them.
    final stats = [
      for (var i = 10; i >= 1; i--) _game('Basketball', 'g$i'),
    ];

    test('draws the most recent games, oldest on the left', () {
      expect(chartGames(stats).map((g) => g['eventName']),
          ['g5', 'g6', 'g7', 'g8', 'g9', 'g10']);
    });

    test('fewer games than the window still run oldest to newest', () {
      expect(chartGames(stats.sublist(7)).map((g) => g['eventName']),
          ['g1', 'g2', 'g3']);
    });
  });

  // Newest first, like everything else here.
  Map<String, dynamic> scored(num points, [String name = '']) =>
      {'sport': 'Basketball', 'eventName': name, 'pointsAwarded': points};

  group('lastGameTrend', () {
    test('needs a game to compare against', () {
      expect(lastGameTrend(const []), isNull);
      expect(lastGameTrend([scored(40)]), isNull);
    });

    test('compares the newest game with the average of the ones before it',
        () {
      // The dashboard screenshot's games: 34, 79, 89, then 105.
      final t = lastGameTrend(
          [scored(105), scored(89), scored(79), scored(34)])!;
      expect(t.latest, 105);
      expect(t.previousAvg, 67); // 67.33…
      expect(t.percent, 56); // against 67.33, not the rounded 67
    });

    test('a drop is negative', () {
      final t = lastGameTrend([scored(30), scored(60)])!;
      expect(t.percent, -50);
    });

    test('no percentage against an average of nothing', () {
      // Tune-ups earn no points, so an athlete can have only zeros before.
      final t = lastGameTrend([scored(25), scored(0), scored(0)])!;
      expect(t.latest, 25);
      expect(t.previousAvg, 0);
      expect(t.percent, isNull);
    });

    test('reads points stored as doubles and treats missing as zero', () {
      final t = lastGameTrend([
        scored(50.0),
        {'sport': 'Basketball'},
        scored(100),
      ])!;
      expect(t.latest, 50);
      expect(t.previousAvg, 50);
      expect(t.percent, 0);
    });
  });

  group('bestGame', () {
    test('picks the highest-scoring game', () {
      expect(
          bestGame([scored(34, 'a'), scored(105, 'b'), scored(79, 'c')])?[
              'eventName'],
          'b');
    });

    test('a tie goes to the more recent game', () {
      expect(bestGame([scored(60, 'newer'), scored(60, 'older')])?['eventName'],
          'newer');
    });

    test('one game is not a best game', () {
      expect(bestGame([scored(90)]), isNull);
      expect(bestGame(const []), isNull);
    });

    test('nothing when every game scored zero', () {
      expect(bestGame([scored(0), scored(0)]), isNull);
    });
  });

  group('boxScoreLine', () {
    test('basketball leads with points', () {
      expect(
          boxScoreLine('Basketball',
              {'points': 28, 'rebounds': 6, 'assists': 4, 'steals': 2}),
          '28 PTS · 6 REB · 4 AST');
    });

    test('volleyball', () {
      expect(boxScoreLine('Volleyball', {'kills': 12, 'aces': 3, 'digs': 8}),
          '12 K · 3 ACE · 8 DIG');
    });

    test('badminton reads the result and pluralises sets', () {
      expect(
          boxScoreLine('Badminton',
              {'matchWon': true, 'setsWon': 2, 'pointsScored': 42}),
          'Win · 2 sets · 42 pts');
      expect(
          boxScoreLine('Badminton',
              {'matchWon': false, 'setsWon': 1, 'pointsScored': 30}),
          'Loss · 1 set · 30 pts');
    });

    test('missing stats read as zero; an unknown sport has no line', () {
      expect(boxScoreLine('Basketball', const {}), '0 PTS · 0 REB · 0 AST');
      expect(boxScoreLine('Chess', {'points': 3}), '');
    });
  });

  group('boxScoreAverages', () {
    Map<String, dynamic> game(String sport, Map<String, dynamic> stats) =>
        {'sport': sport, 'stats': stats};

    test('basketball shows four per-game averages in the Scout order', () {
      final tiles = boxScoreAverages('Basketball', [
        game('Basketball', {'points': 10, 'rebounds': 5, 'assists': 3}),
        game('Basketball', {'points': 15, 'rebounds': 6, 'assists': 4}),
      ]);
      expect(tiles.map((t) => t.label), [
        'Points / game',
        'Rebounds / game',
        'Assists / game',
        'Steals / game',
      ]);
      expect(tiles.map((t) => t.value), ['12.5', '5.5', '3.5', '0']);
    });

    test('volleyball', () {
      final tiles = boxScoreAverages('Volleyball', [
        game('Volleyball', {'kills': 8, 'aces': 2, 'assists': 1, 'digs': 6}),
      ]);
      expect(tiles.map((t) => t.label), [
        'Kills / game',
        'Aces / game',
        'Assists / game',
        'Digs / game',
      ]);
      expect(tiles.map((t) => t.value), ['8', '2', '1', '6']);
    });

    test('badminton has three, with the win rate as a whole percent', () {
      final tiles = boxScoreAverages('Badminton', [
        game('Badminton', {'matchWon': true, 'setsWon': 2, 'pointsScored': 42}),
        game('Badminton', {'matchWon': true, 'setsWon': 2, 'pointsScored': 40}),
        game('Badminton',
            {'matchWon': false, 'setsWon': 1, 'pointsScored': 35}),
      ]);
      expect(tiles.map((t) => t.label),
          ['Win rate', 'Sets won / game', 'Points scored / game']);
      expect(tiles.map((t) => t.value), ['67%', '1.7', '39']);
    });

    test('nothing for no games or an unknown sport', () {
      expect(boxScoreAverages('Basketball', const []), isEmpty);
      expect(boxScoreAverages('Chess', [game('Chess', {'points': 1})]),
          isEmpty);
    });
  });
}
