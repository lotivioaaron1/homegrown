// test/team_carousel_test.dart
//
// Covers TeamCarousel, the presentational half of the home screen's "My Team"
// deck. It is deliberately free of Firebase — TeamCarouselLoader owns the
// hydration and is the part that needs mocks — so the swipe/expand behaviour
// can be tested directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/skeleton.dart';
import 'package:homegrown/widgets/team_carousel.dart';

const _members = [
  TeamMemberView(
      uid: 'c1', name: 'Coach Reyes', subtitle: 'Head Coach', isCoach: true),
  TeamMemberView(uid: 'a1', name: 'John Doe', subtitle: 'Point Guard'),
  TeamMemberView(uid: 'a2', name: 'Maria Cruz', subtitle: 'Shooting Guard'),
];

// Coach, then the viewer, then two teammates — the order home_screen.dart
// and athlete_team_screen.dart now build: self seated right after the coach.
const _membersWithSelf = [
  TeamMemberView(
      uid: 'c1', name: 'Coach Reyes', subtitle: 'Head Coach', isCoach: true),
  TeamMemberView(uid: 'me', name: 'Sam Rivera', subtitle: 'Point Guard', isSelf: true),
  TeamMemberView(uid: 'a1', name: 'John Doe', subtitle: 'Point Guard'),
  TeamMemberView(uid: 'a2', name: 'Maria Cruz', subtitle: 'Shooting Guard'),
];

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('collapsed deck', () {
    testWidgets('shows the team name and count chip', (tester) async {
      await tester.pumpWidget(_host(const TeamCarousel(
          title: 'Legazpi Warriors',
          countLabel: '2 teammates',
          members: _members)));

      expect(find.text('Legazpi Warriors'), findsOneWidget);
      expect(find.text('2 teammates'), findsOneWidget);
    });

    testWidgets('builds the coach card first', (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: _members)));
      await tester.pumpAndSettle();

      // Only the coach carries the badge, and PageView builds from index 0.
      expect(find.text('COACH'), findsOneWidget);
      expect(find.text('Coach Reyes'), findsOneWidget);
    });

    testWidgets('renders nothing when there is no one to show',
        (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: [])));

      expect(find.text('Warriors'), findsNothing);
    });

    testWidgets('swiping advances the deck', (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: _members)));
      await tester.pumpAndSettle();

      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(controller.page?.round(), 0);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(controller.page?.round(), 1);
    });
  });

  group('expanding', () {
    testWidgets('tapping a card swaps the deck for the roster list',
        (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: _members)));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);

      await tester.tap(find.text('Coach Reyes'));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      // Every member is listed once the section is open, including the ones
      // the deck had not built yet.
      expect(find.text('Coach Reyes'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Maria Cruz'), findsOneWidget);
    });

    testWidgets('tapping the header collapses it again', (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: _members)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach Reyes'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);

      await tester.tap(find.text('Warriors'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('a roster row reports the member it belongs to',
        (tester) async {
      TeamMemberView? tapped;
      await tester.pumpWidget(_host(TeamCarousel(
        title: 'Warriors',
        members: _members,
        onMemberTap: (m) => tapped = m,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach Reyes'));
      await tester.pumpAndSettle();

      // Card taps expand; only rows in the open list open a profile.
      expect(tapped, isNull);

      await tester.tap(find.text('Maria Cruz'));
      await tester.pumpAndSettle();

      expect(tapped?.uid, 'a2');
    });
  });

  group('coach affordances', () {
    testWidgets('adds a trailing add-player card when a callback is given',
        (tester) async {
      var added = 0;
      await tester.pumpWidget(_host(TeamCarousel(
        title: 'Warriors',
        members: const [TeamMemberView(uid: 'a1', name: 'John Doe', subtitle: 'PG')],
        onAddPlayer: () => added++,
      )));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add player'));
      expect(added, 1);
    });

    testWidgets('omits it when no callback is given', (tester) async {
      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'Warriors', members: _members)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(find.text('Add player'), findsNothing);
    });
  });

  group('the viewer\'s own card', () {
    testWidgets('is badged YOU and the coach is not', (tester) async {
      await tester.pumpWidget(_host(
          const TeamCarousel(title: 'Warriors', members: _membersWithSelf)));
      await tester.pumpAndSettle();

      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);
    });

    testWidgets('is built second, right after the coach', (tester) async {
      await tester.pumpWidget(_host(
          const TeamCarousel(title: 'Warriors', members: _membersWithSelf)));
      await tester.pumpAndSettle();

      // Page 0 (coach) is centred at rest, so the viewer's card — page 1 —
      // is the visible peek card without swiping at all.
      expect(find.text('Coach Reyes'), findsOneWidget);
      expect(find.text('Sam Rivera'), findsOneWidget);
    });

    testWidgets('keeps the gold ring exclusive to the coach', (tester) async {
      await tester.pumpWidget(_host(
          const TeamCarousel(title: 'Warriors', members: _membersWithSelf)));
      await tester.pumpAndSettle();

      // Both the coach and the self card sit inside a Container whose
      // decoration carries the border; the coach's is 2px accent-coloured,
      // everyone else's — self included — is the standard 1px border.
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => c.decoration as BoxDecoration)
          .where((d) => d.borderRadius == BorderRadius.circular(20));

      final widths = containers
          .map((d) => d.border?.top.width)
          .whereType<double>()
          .toList();
      expect(widths.where((w) => w == 2), hasLength(1),
          reason: 'exactly one card (the coach) should carry the thick ring');
    });

    testWidgets('is marked in the expanded roster and teammates are not',
        (tester) async {
      await tester.pumpWidget(_host(
          const TeamCarousel(title: 'Warriors', members: _membersWithSelf)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach Reyes'));
      await tester.pumpAndSettle();

      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('Sam Rivera'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Maria Cruz'), findsOneWidget);
    });
  });

  group('skeleton', () {
    testWidgets('keeps the deck height so the page does not jump',
        (tester) async {
      await tester.pumpWidget(_host(const TeamCarouselSkeleton(title: 'W')));
      await tester.pump(const Duration(milliseconds: 100));

      final loading = tester.getSize(find.byType(TeamCarouselSkeleton));

      await tester.pumpWidget(
          _host(const TeamCarousel(title: 'W', members: _members)));
      await tester.pumpAndSettle();

      final loaded = tester.getSize(find.byType(TeamCarousel));
      // Only the header differs — the real one carries a chip and a chevron
      // taller than the placeholder's title line. Anything more than that
      // means the section visibly resizes when data lands.
      expect((loading.height - loaded.height).abs(), lessThan(12));
    });

    testWidgets('stubs the title when it is not known yet', (tester) async {
      await tester.pumpWidget(_host(const TeamCarouselSkeleton()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('reduced motion', () {
    testWidgets('still expands with animations disabled', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TeamCarousel(title: 'Warriors', members: _members),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach Reyes'));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Maria Cruz'), findsOneWidget);
    });
  });
}
