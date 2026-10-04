// test/widgets/points_trend_card_test.dart
//
// The trend card on the performance dashboard: the latest game as the
// headline, the pill comparing it with the athlete's average before it, and
// a line whose axis keeps numbering games correctly once there are more of
// them than it plots. Which game is "best" and how the trend is worked out
// are covered by test/utils/stats_view_test.dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:homegrown/theme/app_theme.dart';
import 'package:homegrown/widgets/points_trend_card.dart';

/// [points] oldest first, returned newest first the way the dashboard
/// sorts its games.
List<Map<String, dynamic>> _games(List<int> points) => [
      for (var i = 0; i < points.length; i++)
        {
          'sport': 'Basketball',
          'eventName': 'Game ${i + 1}',
          'pointsAwarded': points[i],
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1 + i)),
        },
    ].reversed.toList();

// GetMaterialApp, as in the other widget tests: AppTheme's getters are read
// under Get's theme in the app.
Widget _host(List<Map<String, dynamic>> games, {double width = 360}) =>
    GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: PointsTrendCard(games: games)),
        ),
      ),
    );

void main() {
  setUp(() => AppTheme.isDark = false);
  tearDown(() => AppTheme.isDark = false);

  testWidgets('leads with the latest game and how it compares',
      (tester) async {
    // The athlete in the dashboard screenshot: 34, 79, 89, then 105.
    await tester.pumpWidget(_host(_games([34, 79, 89, 105])));
    await tester.pumpAndSettle();

    expect(find.text('105'), findsOneWidget);
    expect(find.text('PTS · LAST GAME'), findsOneWidget);
    expect(find.text('56%'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);
    expect(find.text('vs your avg of 67'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    for (final g in ['G1', 'G2', 'G3', 'G4']) {
      expect(find.text(g), findsOneWidget);
    }
  });

  testWidgets('touching a game puts it in the headline until release',
      (tester) async {
    await tester.pumpWidget(_host(_games([20, 45, 70])));
    await tester.pumpAndSettle();

    // The middle of the plot is the middle game (Sep 2, 45 pts).
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(LineChart)));
    await tester.pump();

    expect(find.text('45'), findsOneWidget);
    expect(find.text('PTS · SEP 2'), findsOneWidget);
    expect(find.text('Game 2'), findsOneWidget);
    expect(find.text('PTS · LAST GAME'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('70'), findsOneWidget);
    expect(find.text('PTS · LAST GAME'), findsOneWidget);
    expect(find.text('Game 2'), findsNothing);
  });

  testWidgets('a drop points down', (tester) async {
    await tester.pumpWidget(_host(_games([60, 30])));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingDown), findsOneWidget);
  });

  testWidgets('a game level with the average says so', (tester) async {
    await tester.pumpWidget(_host(_games([40, 40])));
    await tester.pumpAndSettle();

    expect(find.text('On par'), findsOneWidget);
  });

  testWidgets('no pill against an average of zero', (tester) async {
    // Tune-ups before the first scored game.
    await tester.pumpWidget(_host(_games([0, 0, 25])));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('vs your avg'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('one game: a headline but no line yet', (tester) async {
    await tester.pumpWidget(_host(_games([34])));
    await tester.pumpAndSettle();

    expect(find.text('34'), findsOneWidget);
    expect(find.text('Your trend line appears after your next game.'),
        findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('past the window, the axis keeps the real game numbers',
      (tester) async {
    await tester.pumpWidget(
        _host(_games([for (var i = 1; i <= 25; i++) i * 3])));
    await tester.pumpAndSettle();

    // Games 16–25 plotted, every other one labelled, counting back from the
    // newest so it is always named.
    for (final g in ['G25', 'G23', 'G21', 'G19', 'G17']) {
      expect(find.text(g), findsOneWidget);
    }
    for (final g in ['G24', 'G16', 'G15', 'G1']) {
      expect(find.text(g), findsNothing);
    }
    expect(find.text('Your last 10 of 25 games'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'fits a 320px phone in ${dark ? 'dark' : 'light'} mode at every size',
        (tester) async {
      AppTheme.isDark = dark;
      for (final n in [1, 2, 10, 25]) {
        await tester.pumpWidget(
            _host(_games([for (var i = 0; i < n; i++) (i * 37) % 120]),
                width: 320));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$n games');
      }
    });
  }
}
