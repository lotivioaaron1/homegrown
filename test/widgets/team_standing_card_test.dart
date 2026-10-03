// test/widgets/team_standing_card_test.dart
//
// The team screens' standing card: what each line says, what shows when the
// team hasn't played, and that a tap opens the right sport's table.
//
// TeamStandingCard itself reads Firebase and can't be pumped here (this
// project has no Firestore mocks), so the drawing lives in TeamStandingView
// and the choice of lines in linesToShow, both tested directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/utils/team_standings.dart';
import 'package:homegrown/widgets/team_standing_card.dart';

final _now = DateTime.utc(2026, 6, 1);

StandingsGame _game(String a, String b, int scoreA, int scoreB) =>
    StandingsGame(
      coachA: a,
      coachB: b,
      nameA: 'Team $a',
      nameB: 'Team $b',
      scoreA: scoreA,
      scoreB: scoreB,
      playedAt: _now,
    );

/// [coach]'s line in a table built from [games].
TeamStandingLine _line(String sport, String coach, List<StandingsGame> games) {
  final table = computeStandings(games);
  return TeamStandingLine(
    sport: sport,
    season: 2026,
    place: placeOf(table, standingRanks(table), coach),
    teams: table.length,
  );
}

Widget _host(List<TeamStandingLine> lines, {void Function(String)? onOpen}) =>
    GetMaterialApp(
      home: Scaffold(
        body: TeamStandingView(lines: lines, onOpen: onOpen ?? (_) {}),
      ),
    );

void main() {
  // me: 1-1 (+5), 2nd of 3 behind a, ahead of b.
  final played = [
    _game('a', 'me', 70, 60),
    _game('me', 'b', 80, 65),
  ];

  testWidgets('a team that has played shows its place and record',
      (tester) async {
    await tester.pumpWidget(_host([_line('Basketball', 'me', played)]));

    expect(find.text('2nd of 3'), findsOneWidget);
    expect(find.text('Basketball 2026 · 1–1 · .500 · +5'), findsOneWidget);
  });

  testWidgets('a shared place says it is tied', (tester) async {
    final level = [_game('x', 'me', 60, 50), _game('x', 'b', 60, 50)];
    await tester.pumpWidget(_host([_line('Basketball', 'me', level)]));

    expect(find.text('Tied 2nd of 3'), findsOneWidget);
  });

  testWidgets('a team with no games yet still points at the standings',
      (tester) async {
    await tester.pumpWidget(_host([_line('Volleyball', 'me', [])]));

    expect(find.text('No official games yet'), findsOneWidget);
    expect(find.text('Volleyball 2026 · See standings'), findsOneWidget);
  });

  testWidgets('tapping a line opens that sport', (tester) async {
    String? opened;
    await tester.pumpWidget(_host([
      _line('Basketball', 'me', played),
      _line('Volleyball', 'me', [_game('me', 'z', 3, 1)]),
    ], onOpen: (sport) => opened = sport));

    await tester.tap(find.text('1st of 2'));
    expect(opened, 'Volleyball');
  });

  testWidgets('fits a 320dp phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TeamStandingView(
              lines: [_line('Volleyball', 'me', played)], onOpen: (_) {}),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  group('linesToShow', () {
    test('keeps only the sports the team has played', () {
      final lines = linesToShow([
        _line('Basketball', 'me', played),
        _line('Volleyball', 'me', []),
      ]);
      expect(lines.map((l) => l.sport), ['Basketball']);
    });

    test('keeps every sport played by a two-sport team', () {
      final lines = linesToShow([
        _line('Basketball', 'me', played),
        _line('Volleyball', 'me', [_game('me', 'z', 3, 1)]),
      ]);
      expect(lines.map((l) => l.sport), ['Basketball', 'Volleyball']);
    });

    test('falls back to the first sport when nothing has been played', () {
      final lines = linesToShow([
        _line('Basketball', 'me', []),
        _line('Volleyball', 'me', []),
      ]);
      expect(lines.map((l) => l.sport), ['Basketball']);
      expect(lines.single.place, isNull);
    });

    test('is empty for a coach with no sports set', () {
      expect(linesToShow([]), isEmpty);
    });
  });
}
