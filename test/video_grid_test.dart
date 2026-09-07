// test/video_grid_test.dart
//
// Covers VideoGrid, the presentational half of the profile's highlight reel.
// Like TeamCarousel it is deliberately free of Firebase — MediaSection and
// ProfileScreen own the stream — so the grid's formatting and tap behaviour
// can be exercised directly from MediaItem fixtures.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/media_item.dart';
import 'package:homegrown/screens/profile/widgets/empty_state.dart';
import 'package:homegrown/screens/profile/widgets/video_grid.dart';

MediaItem _video({
  String id = 'v1',
  int? durationSeconds = 42,
  String caption = '',
}) =>
    MediaItem(
      id: id,
      type: MediaType.video,
      // Left empty so CachedNetworkImage resolves to its error widget rather
      // than reaching for the network mid-test.
      url: '',
      thumbnailUrl: '',
      category: MediaCategory.game,
      caption: caption,
      createdAt: DateTime(2026, 1, 1),
      sizeBytes: 1024,
      durationSeconds: durationSeconds,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('formatClipDuration', () {
    test('pads the seconds so 1:05 never renders as 1:5', () {
      expect(formatClipDuration(65), '1:05');
    });

    test('renders a sub-minute clip with a leading zero minute', () {
      expect(formatClipDuration(42), '0:42');
    });

    test('renders the 60-second cap as a round minute', () {
      expect(formatClipDuration(60), '1:00');
    });

    test('returns empty for a null duration rather than "0:00"', () {
      // Photos carry no duration, and an unmigrated video doc may not either.
      // Showing "0:00" would claim the clip is empty.
      expect(formatClipDuration(null), '');
    });
  });

  group('VideoGrid', () {
    testWidgets('shows the empty state when there are no highlights',
        (tester) async {
      await tester.pumpWidget(_host(const VideoGrid(items: [])));

      expect(find.byType(EmptyState), findsOneWidget);
      expect(
          find.textContaining('No highlights yet'), findsOneWidget);
    });

    testWidgets('renders a duration badge per tile', (tester) async {
      await tester.pumpWidget(_host(VideoGrid(items: [
        _video(id: 'v1', durationSeconds: 65),
        _video(id: 'v2', durationSeconds: 8),
      ])));

      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);
    });

    testWidgets('omits the badge when a clip has no duration', (tester) async {
      await tester
          .pumpWidget(_host(VideoGrid(items: [_video(durationSeconds: null)])));

      expect(find.textContaining(':'), findsNothing);
    });

    testWidgets('reports the tapped item to onTapItem', (tester) async {
      MediaItem? tapped;
      await tester.pumpWidget(_host(VideoGrid(
        items: [_video(id: 'first'), _video(id: 'second')],
        onTapItem: (item) => tapped = item,
      )));

      await tester.tap(find.byType(GestureDetector).last);
      expect(tapped?.id, 'second');
    });

    testWidgets('tiles are inert when no tap handler is given',
        (tester) async {
      // The same grid is reused for viewing another athlete's portfolio,
      // where tapping through to a delete-capable viewer would be wrong.
      await tester.pumpWidget(_host(VideoGrid(items: [_video()])));

      final detector =
          tester.widget<GestureDetector>(find.byType(GestureDetector).first);
      expect(detector.onTap, isNull);
    });
  });
}
