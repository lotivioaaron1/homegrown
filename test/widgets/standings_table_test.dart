// test/widgets/standings_table_test.dart
//
// The standings card is six columns on a phone. It has to fit the narrowest
// supported screen (320dp) without overflowing, whatever the team is called
// and however lopsided the scores, and it has to mark the viewer's team with
// words, not just a colour.
//
// The 320dp test proves the row's structure holds (fixed number columns, the
// name taking what's left). It can't prove each number fits its column: the
// test font draws every glyph a full em wide, far wider than the Roboto the
// app renders in, so the column widths themselves are checked on a device.
//
// StandingsScreen itself can't be pumped (it reaches Firebase in initState and
// this project has no Firestore mocks), which is why the card is its own
// widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/utils/team_standings.dart';
import 'package:homegrown/widgets/standings_table.dart';

const _long = TeamStanding(
  coachId: 'long',
  storedName: 'Barangay Bagumbayan Mighty Hoopers Basketball Club',
  wins: 128,
  losses: 99,
  pointsFor: 18000,
  pointsAgainst: 17001,
);

const _beaten = TeamStanding(
  coachId: 'beaten',
  storedName: 'Rawis Rockets',
  wins: 0,
  losses: 7,
  pointsFor: 300,
  pointsAgainst: 999,
);

// GetMaterialApp, not MaterialApp: AppTheme's semantic getters switch on
// Get.isDarkMode, which needs Get's theme in scope.
Widget _host({
  Set<String> myTeams = const {},
  void Function(String, Map<String, dynamic>?, String)? onOpen,
}) =>
    GetMaterialApp(
      home: Scaffold(
        body: ListView(
          // The screen's own side padding.
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            StandingsTable(
              table: const [_long, _beaten],
              ranks: const [1, 2],
              coaches: const {
                'beaten': {'teamOrganization': 'Rawis Rockets'},
              },
              myTeams: myTeams,
              onOpen: onOpen ?? (_, __, ___) {},
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('fits a 320dp phone with long names and big numbers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(myTeams: {'long'}));

    // An overflow is reported as an exception on the tester.
    expect(tester.takeException(), isNull);
    expect(find.text('.564'), findsOneWidget);
    expect(find.text('+999'), findsOneWidget);
    expect(find.text('−699'), findsOneWidget);
  });

  test('the sample numbers above are what they claim', () {
    expect(formatPct(_long.winPct), '.564');
    expect(_long.diff, 999);
    expect(_beaten.diff, -699);
  });

  testWidgets("the viewer's team is labelled, not only coloured",
      (tester) async {
    await tester.pumpWidget(_host(myTeams: {'beaten'}));
    expect(find.text('YOUR TEAM'), findsOneWidget);

    await tester.pumpWidget(_host());
    expect(find.text('YOUR TEAM'), findsNothing);
  });

  testWidgets('uses the live team name, else the last name played under',
      (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Rawis Rockets'), findsOneWidget);
    expect(find.text(_long.storedName), findsOneWidget);
  });

  testWidgets('tapping a row opens that team', (tester) async {
    String? opened;
    await tester.pumpWidget(_host(onOpen: (coachId, _, __) => opened = coachId));

    await tester.tap(find.text('Rawis Rockets'));
    expect(opened, 'beaten');
  });

  testWidgets('each row reads as one sentence to a screen reader',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(myTeams: {'beaten'}));

    expect(
      find.bySemanticsLabel('Rank 2, Rawis Rockets, your team, 0 wins, '
          '7 losses, win percentage .000, point difference −699'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
