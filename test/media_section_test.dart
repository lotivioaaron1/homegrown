// test/media_section_test.dart
//
// Covers MediaSection — the quota counter and grid selection that both
// portfolio sections share. It takes a plain list rather than a stream
// (ProfileScreen owns the single Firestore listener), which is what lets this
// run without Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:homegrown/models/media_item.dart';
import 'package:homegrown/screens/profile/widgets/media_section.dart';
import 'package:homegrown/screens/profile/widgets/photo_grid.dart';
import 'package:homegrown/screens/profile/widgets/video_grid.dart';
import 'package:homegrown/theme/app_theme.dart';
import 'package:homegrown/widgets/skeleton.dart';

MediaItem _item(MediaType type, String id) => MediaItem(
      id: id,
      type: type,
      url: '',
      thumbnailUrl: '',
      category: MediaCategory.game,
      caption: '',
      createdAt: DateTime(2026, 1, 1),
      sizeBytes: 1024,
      durationSeconds: type == MediaType.video ? 30 : null,
    );

List<MediaItem> _photos(int n) =>
    List.generate(n, (i) => _item(MediaType.photo, 'p$i'));

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _photoSection({
  required List<MediaItem> items,
  bool loading = false,
  int max = 20,
}) =>
    MediaSection(
      items: items,
      loading: loading,
      max: max,
      type: MediaType.photo,
      title: 'Photo Highlights',
      icon: LucideIcons.image,
    );

void main() {
  testWidgets('shows the used-of-quota count in the header', (tester) async {
    await tester.pumpWidget(_host(_photoSection(items: _photos(14))));

    expect(find.text('14 / 20'), findsOneWidget);
  });

  testWidgets('shows the count at zero rather than hiding it', (tester) async {
    // The cap should be discoverable before the first upload, not only once
    // photos exist.
    await tester.pumpWidget(_host(_photoSection(items: const [])));

    expect(find.text('0 / 20'), findsOneWidget);
  });

  testWidgets('renders the at-cap count when the quota is used up',
      (tester) async {
    await tester.pumpWidget(_host(_photoSection(items: _photos(20))));

    expect(find.text('20 / 20'), findsOneWidget);
  });

  testWidgets('withholds the count while loading', (tester) async {
    // Showing "0 / 20" before the real number arrives would read as an empty
    // portfolio for a moment, which is worse than showing nothing.
    await tester
        .pumpWidget(_host(_photoSection(items: const [], loading: true)));

    expect(find.textContaining('/ 20'), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('renders the photo grid for a photo section', (tester) async {
    await tester.pumpWidget(_host(_photoSection(items: _photos(2))));

    expect(find.byType(PhotoGrid), findsOneWidget);
    expect(find.byType(VideoGrid), findsNothing);
  });

  testWidgets('renders the video grid for a video section', (tester) async {
    await tester.pumpWidget(_host(MediaSection(
      items: [_item(MediaType.video, 'v0')],
      max: 3,
      type: MediaType.video,
      title: 'Video Highlights',
      icon: LucideIcons.video,
    )));

    expect(find.byType(VideoGrid), findsOneWidget);
    expect(find.byType(PhotoGrid), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('shows the section title', (tester) async {
    await tester.pumpWidget(_host(_photoSection(items: const [])));

    expect(find.text('Photo Highlights'), findsOneWidget);
  });

  // ── Viewing someone else's portfolio ──────
  // A coach scouting or a teammate looking is shown the same sections, but
  // the owner-facing quota and copy are wrong in that context.

  group('viewed by someone other than the owner', () {
    testWidgets('drops the quota denominator from the count', (tester) async {
      await tester.pumpWidget(_host(MediaSection(
        items: _photos(14),
        max: 20,
        type: MediaType.photo,
        title: 'Photo Highlights',
        icon: LucideIcons.image,
        showQuota: false,
      )));

      expect(find.text('14'), findsOneWidget);
      expect(find.text('14 / 20'), findsNothing);
    });

    testWidgets('never flags the at-cap warning', (tester) async {
      // At 20/20 the owner sees an amber "you cannot upload more" counter.
      // To a viewer that would read as a limit on what they may look at.
      await tester.pumpWidget(_host(MediaSection(
        items: _photos(20),
        max: 20,
        type: MediaType.photo,
        title: 'Photo Highlights',
        icon: LucideIcons.image,
        showQuota: false,
      )));

      final label = tester.widget<Text>(find.text('20'));
      expect(label.style?.color, isNot(AppTheme.warning));
    });

    testWidgets('passes viewer-facing empty copy down to the grid',
        (tester) async {
      await tester.pumpWidget(_host(const MediaSection(
        items: [],
        max: 3,
        type: MediaType.video,
        title: 'Video Highlights',
        icon: LucideIcons.video,
        showQuota: false,
        emptyMessage: 'No highlights yet.\nNothing uploaded.',
      )));

      expect(find.text('No highlights yet.\nNothing uploaded.'), findsOneWidget);
      // The owner-voiced default must not survive into a viewer's screen.
      expect(find.textContaining('Upload your best plays'), findsNothing);
    });
  });
}
