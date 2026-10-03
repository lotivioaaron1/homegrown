// test/widgets/next_game_card_test.dart
//
// The "Next game" card on Home. NextGameCard itself streams from Firestore and
// can't be pumped here (this project has no Firestore mocks), so the drawing
// lives in NextGameView and is tested directly; which game it shows is covered
// by test/utils/next_game_test.dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:homegrown/widgets/next_game_card.dart';

// Saturday 3 Oct 2026, 9:00 AM.
final _now = DateTime(2026, 10, 3, 9);

Map<String, dynamic> _event({
  required DateTime date,
  String name = 'Shohoku vs Rawis Rockets',
  String venue = 'Ibalong Centrum for Recreation',
}) =>
    {
      'name': name,
      'venue': venue,
      'sport': 'Basketball',
      'eventDate': Timestamp.fromDate(date),
    };

Widget _host(Map<String, dynamic> event,
        {VoidCallback? onTap, double width = 400, double textScale = 1}) =>
    GetMaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: NextGameView(
                  event: event, now: _now, onTap: onTap ?? () {}),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('leads with the kickoff, then the game and the venue',
      (tester) async {
    await tester.pumpWidget(_host(_event(date: DateTime(2026, 10, 4, 16))));

    expect(find.text('NEXT GAME'), findsOneWidget);
    expect(find.text('Tomorrow · 4:00 PM'), findsOneWidget);
    expect(find.text('Shohoku vs Rawis Rockets'), findsOneWidget);
    expect(find.text('Ibalong Centrum for Recreation'), findsOneWidget);
  });

  testWidgets('says GAME DAY when the game is today', (tester) async {
    await tester.pumpWidget(_host(_event(date: DateTime(2026, 10, 3, 18))));

    expect(find.text('GAME DAY'), findsOneWidget);
    expect(find.text('NEXT GAME'), findsNothing);
    expect(find.text('Today · 6:00 PM'), findsOneWidget);
  });

  testWidgets('a game with no venue drops the venue line', (tester) async {
    await tester.pumpWidget(
        _host(_event(date: DateTime(2026, 10, 10, 16), venue: '  ')));

    expect(find.text('Sat, Oct 10 · 4:00 PM'), findsOneWidget);
    expect(find.byIcon(LucideIcons.mapPin), findsNothing);
    expect(find.text('  '), findsNothing);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        _host(_event(date: DateTime(2026, 10, 4, 16)), onTap: () => taps++));

    await tester.tap(find.byType(NextGameView));
    expect(taps, 1);
  });

  testWidgets('long names fit a 320dp phone at large text without overflow',
      (tester) async {
    await tester.pumpWidget(_host(
      _event(
        date: DateTime(2026, 10, 10, 16),
        name: 'Barangay Sports Festival — Semifinal: Shohoku vs '
            'Tamaoyan Tigers of Legazpi City',
        venue: 'Albay Astrodome, Rizal Street, Legazpi City, Albay',
      ),
      width: 320,
      textScale: 1.5,
    ));

    expect(tester.takeException(), isNull);
  });
}
