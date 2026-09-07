// test/media_viewers_test.dart
//
// Covers the photo and highlight viewers' owner-vs-viewer split. Both were
// written when only the athlete who uploaded the media could ever open it, so
// both hardcoded a delete control. Now that coaches and teammates open the
// same viewers, `onDelete` is what separates the two cases — and a delete
// affordance offered to someone who cannot delete is the regression these
// tests exist to catch.
//
// Deliberately Firebase-free: both viewers take a MediaItem and render it, so
// the fixtures below are enough.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:homegrown/models/media_item.dart';
import 'package:homegrown/widgets/photo_viewer_dialog.dart';
import 'package:homegrown/widgets/video_player_sheet.dart';

MediaItem _photo({String caption = ''}) => MediaItem(
      id: 'p1',
      type: MediaType.photo,
      // Left empty so CachedNetworkImage resolves to its error widget rather
      // than reaching for the network mid-test.
      url: '',
      thumbnailUrl: '',
      category: MediaCategory.award,
      caption: caption,
      createdAt: DateTime(2026, 1, 1),
      sizeBytes: 1024,
    );

/// Pumps a screen whose only job is to open [open] when tapped — dialogs need
/// a route to sit above, so they cannot be pumped directly.
///
/// GetMaterialApp, not MaterialApp: the delete path dismisses the dialog with
/// `Get.back()` before running the callback, which needs GetX's navigator.
Future<void> _openFrom(
  WidgetTester tester,
  void Function(BuildContext) open,
) async {
  await tester.pumpWidget(GetMaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  group('photo viewer', () {
    testWidgets('offers a delete control to the owner', (tester) async {
      await _openFrom(
        tester,
        (context) => showPhotoViewer(context, _photo(), onDelete: () {}),
      );

      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    });

    testWidgets('shows no delete control when someone else is looking',
        (tester) async {
      await _openFrom(tester, (context) => showPhotoViewer(context, _photo()));

      expect(find.byIcon(LucideIcons.trash2), findsNothing);
    });

    testWidgets('runs the owner callback on tap', (tester) async {
      var deleted = false;
      await _openFrom(
        tester,
        (context) =>
            showPhotoViewer(context, _photo(), onDelete: () => deleted = true),
      );
      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('still shows the category and caption to a viewer',
        (tester) async {
      // The metadata is the point of the bar; only the delete control is
      // owner-only.
      await _openFrom(
        tester,
        (context) => showPhotoViewer(context, _photo(caption: 'MVP night')),
      );

      expect(find.text('Award'), findsOneWidget);
      expect(find.text('MVP night'), findsOneWidget);
    });

    testWidgets('falls back to "No caption" for an uncaptioned photo',
        (tester) async {
      await _openFrom(tester, (context) => showPhotoViewer(context, _photo()));

      expect(find.text('No caption'), findsOneWidget);
    });
  });

  group('highlight player', () {
    // The player itself needs a real video to initialize, so these drive the
    // meta bar directly — that is where the owner/viewer split lives.
    Widget host(VoidCallback? onDelete) => MaterialApp(
          home: Scaffold(
            body: VideoHighlightDialog(
              item: MediaItem(
                id: 'v1',
                type: MediaType.video,
                url: '',
                thumbnailUrl: '',
                category: MediaCategory.game,
                caption: 'Buzzer beater',
                createdAt: DateTime(2026, 1, 1),
                sizeBytes: 2048,
                durationSeconds: 42,
              ),
              onDelete: onDelete,
            ),
          ),
        );

    testWidgets('offers a delete control to the owner', (tester) async {
      await tester.pumpWidget(host(() {}));
      await tester.pump();

      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    });

    testWidgets('shows no delete control when someone else is watching',
        (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pump();

      expect(find.byIcon(LucideIcons.trash2), findsNothing);
      // The caption still renders — the viewer loses the control, not the
      // context around the clip.
      expect(find.text('Buzzer beater'), findsOneWidget);
    });
  });
}
