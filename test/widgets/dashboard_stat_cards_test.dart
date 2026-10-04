// test/widgets/dashboard_stat_cards_test.dart
//
// The Best Game card and the per-game averages grid on the performance
// dashboard. The numbers themselves come from lib/utils/stats_view.dart and
// are covered in test/utils/stats_view_test.dart; these check what is drawn
// and that it fits a small phone.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/theme/app_theme.dart';
import 'package:homegrown/widgets/best_game_card.dart';
import 'package:homegrown/widgets/stat_averages_grid.dart';

Widget _host(Widget child, {double width = 320}) => GetMaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

void main() {
  setUp(() => AppTheme.isDark = false);
  tearDown(() => AppTheme.isDark = false);

  group('BestGameCard', () {
    final game = {
      'sport': 'Basketball',
      'eventName': 'asd — Final: Coach vs Team Test',
      'pointsAwarded': 105,
      'venue': 'Ibalong Centrum for Recreation',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 29)),
      'stats': {'points': 28, 'rebounds': 6, 'assists': 4},
    };

    testWidgets('names the game with its box score, date and venue',
        (tester) async {
      await tester.pumpWidget(_host(BestGameCard(game: game)));

      expect(find.text('BEST GAME'), findsOneWidget);
      expect(find.text('asd — Final: Coach vs Team Test'), findsOneWidget);
      expect(
          find.text('28 PTS · 6 REB · 4 AST · Sep 29 · '
              'Ibalong Centrum for Recreation'),
          findsOneWidget);
      expect(find.text('+105'), findsOneWidget);
    });

    testWidgets('leaves out a venue that was never recorded', (tester) async {
      await tester.pumpWidget(
          _host(BestGameCard(game: {...game, 'venue': ''})));

      expect(find.text('28 PTS · 6 REB · 4 AST · Sep 29'), findsOneWidget);
    });

    testWidgets('a long event name fits in dark mode', (tester) async {
      AppTheme.isDark = true;
      await tester.pumpWidget(_host(BestGameCard(game: {
        ...game,
        'eventName': 'Legazpi City Inter-Barangay Summer League — '
            'Quarterfinal: Bitano Bulls vs Rawis Rockets',
      })));

      expect(tester.takeException(), isNull);
    });
  });

  group('StatAveragesGrid', () {
    Map<String, dynamic> played(String sport, Map<String, dynamic> stats) =>
        {'sport': sport, 'stats': stats};

    testWidgets('basketball: four tiles', (tester) async {
      await tester.pumpWidget(_host(StatAveragesGrid(sport: 'Basketball', games: [
        played('Basketball',
            {'points': 10, 'rebounds': 5, 'assists': 3, 'steals': 1}),
        played('Basketball',
            {'points': 15, 'rebounds': 6, 'assists': 4, 'steals': 2}),
      ])));

      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('Points / game'), findsOneWidget);
      expect(find.text('Rebounds / game'), findsOneWidget);
      expect(find.text('Assists / game'), findsOneWidget);
      expect(find.text('Steals / game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('badminton: three across, fitting a 320px phone',
        (tester) async {
      await tester.pumpWidget(_host(StatAveragesGrid(sport: 'Badminton', games: [
        played('Badminton',
            {'matchWon': true, 'setsWon': 2, 'pointsScored': 42}),
      ])));

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Win rate'), findsOneWidget);
      expect(find.text('Points scored / game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing for a sport without categories', (tester) async {
      await tester.pumpWidget(_host(StatAveragesGrid(
          sport: 'Chess', games: [played('Chess', {'points': 1})])));

      expect(find.byType(Text), findsNothing);
    });
  });
}
