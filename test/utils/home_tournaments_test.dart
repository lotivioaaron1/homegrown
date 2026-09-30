import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/home_tournaments.dart';

Tournament _t(String id, {String status = Tournament.statusActive}) =>
    Tournament(
      id: id,
      organizerId: 'org',
      name: 'Cup $id',
      sport: 'Basketball',
      status: status,
    );

List<String> _ids(List<Tournament> ts) => ts.map((t) => t.id).toList();

void main() {
  group('homeTournaments', () {
    test('nothing for an organizer with no tournaments', () {
      expect(homeTournaments(const []), isEmpty);
    });

    test('only the newest when none is in progress', () {
      final shown = homeTournaments([
        _t('c', status: Tournament.statusCompleted),
        _t('b', status: Tournament.statusCancelled),
        _t('a', status: Tournament.statusCompleted),
      ]);
      expect(_ids(shown), ['c']);
    });

    test('a newest cancelled one still stands in when none is running', () {
      final shown = homeTournaments([
        _t('b', status: Tournament.statusCancelled),
        _t('a', status: Tournament.statusCompleted),
      ]);
      expect(_ids(shown), ['b']);
    });

    test('every one in progress, in the order given, finished ones left out',
        () {
      final shown = homeTournaments([
        _t('basketball'),
        _t('volleyball'),
        _t('football'),
        _t('old', status: Tournament.statusCompleted),
      ]);
      expect(_ids(shown), ['basketball', 'volleyball', 'football']);
    });

    test('a newer finished one does not push out the running ones', () {
      final shown = homeTournaments([
        _t('done', status: Tournament.statusCompleted),
        _t('x'),
        _t('y'),
      ]);
      expect(_ids(shown), ['x', 'y']);
    });

    test('capped at max, newest first', () {
      final shown = homeTournaments([
        for (final id in ['1', '2', '3', '4', '5']) _t(id),
      ]);
      expect(_ids(shown), ['1', '2', '3']);
    });

    test('max can be changed', () {
      final shown = homeTournaments([_t('1'), _t('2'), _t('3')], max: 2);
      expect(_ids(shown), ['1', '2']);
    });
  });
}
