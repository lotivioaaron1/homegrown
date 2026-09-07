// test/widgets/organizer_profile_parts_test.dart
//
// Covers the two Firebase-free pieces of the organizer's public identity.
//
// OrganizerByline and OrganizerProfileViewScreen cannot be pumped: both reach
// FirebaseFirestore.instance, and this project has no Firestore mocks — the
// same limitation recorded for LoginScreen at gradient_button_test.dart:5-10.
// Splitting the badge and the card out of the byline is what makes the part
// that actually branches reachable here.
//
// The badge carries the load-bearing decision of the whole feature: a public
// profile must show "approved" and must stay silent about every other state,
// including the absent one. `organizerStatus` is never written at all by
// google_profile_setup_screen.dart, so an organizer who signed up with Google
// has no such field — reusing ProfileScreen's private badge, whose default arm
// reads "Pending Review", would brand every one of them permanently.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/widgets/organizer_profile_parts.dart';

// GetMaterialApp, not MaterialApp: AppTheme's semantic getters switch on
// Get.isDarkMode, which needs Get's theme in scope.
Widget _hostBadge(String? status) => GetMaterialApp(
      home: Scaffold(
        body: Center(child: OrganizerApprovedBadge(status: status)),
      ),
    );

Widget _hostCard({
  String name = 'Juan Dela Cruz',
  bool approved = false,
  VoidCallback? onTap,
}) =>
    GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: OrganizerBylineCard(
              name: name, approved: approved, onTap: onTap),
        ),
      ),
    );

void main() {
  group('OrganizerApprovedBadge', () {
    testWidgets('shows the badge for an approved organizer', (tester) async {
      await tester.pumpWidget(_hostBadge('approved'));

      expect(find.text('Approved Organizer'), findsOneWidget);
    });

    // The four states a stranger must never be shown. 'pending', 'rejected'
    // and 'revoked' are internal moderation states; null is every Google
    // signup. All four render nothing at all, not a different label.
    for (final status in <String?>[null, '', 'pending', 'rejected', 'revoked']) {
      testWidgets('renders nothing for ${status ?? 'a missing status'}',
          (tester) async {
        await tester.pumpWidget(_hostBadge(status));

        expect(find.text('Approved Organizer'), findsNothing);
        expect(find.byType(Icon), findsNothing);
      });
    }
  });

  group('OrganizerBylineCard', () {
    testWidgets('renders the organizer name', (tester) async {
      await tester.pumpWidget(_hostCard());

      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('ORGANIZED BY'), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_hostCard(onTap: () => taps++));

      await tester.tap(find.byType(OrganizerBylineCard));
      await tester.pump();

      expect(taps, 1);
    });

    // A card with no destination must not advertise one. This is what a
    // deleted account and the still-loading state both render as.
    testWidgets('drops the chevron when it cannot be opened', (tester) async {
      await tester.pumpWidget(_hostCard(onTap: null));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('keeps the chevron when it can be opened', (tester) async {
      await tester.pumpWidget(_hostCard(onTap: () {}));

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
