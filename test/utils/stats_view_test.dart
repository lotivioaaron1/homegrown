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
}
