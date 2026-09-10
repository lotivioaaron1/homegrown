// lib/screens/events/my_events_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../constants/query_limits.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/event_history.dart';
import '../../utils/firestore_helpers.dart';

const _kRadius = 16.0;

/// The organizer's own events, split into Upcoming and Past.
///
/// Structured after [TournamentListScreen], the organizer's other list screen,
/// rather than after the "View All Events" sheet on the home screen. The sheet
/// covers all three roles and stays where it is; this screen is the organizer's
/// own board, reached from the Events tab in the bottom nav.
///
/// The segmented toggle and the row layout are deliberately duplicated from
/// `_EventTabToggle` and `_EventList` in home_screen.dart rather than extracted
/// out of it: those are private to a 2,000-line screen that works, and copying
/// forty lines is the cheaper risk.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  /// Held in State, not built in `build`: the Upcoming/Past toggle calls
  /// setState, and a stream created inside `build` would tear down and
  /// re-subscribe the Firestore listener on every tap.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Equality-only, and deliberately without an orderBy. Adding
    // .orderBy('eventDate') alongside the organizerId filter would need a new
    // composite index and a deploy; an equality-only query is served by
    // merging single-field indexes. Every other organizer-scoped event query
    // in the app is shaped this way and sorts client-side — see the note in
    // event_reminder_service.dart.
    _stream = FirebaseFirestore.instance
        .collection('events')
        .where('organizerId', isEqualTo: uid)
        .limit(kMaxListQuery)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textPrimary, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text('My Events',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed('/events/create'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.accentSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent)),
                  child: Row(children: [
                    Icon(Icons.add_rounded,
                        color: AppTheme.accentText, size: 15),
                    const SizedBox(width: 4),
                    Text('New',
                        style: TextStyle(
                            color: AppTheme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              _EventTabToggle(
                showPast: _showPast,
                onChanged: (value) => setState(() => _showPast = value),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2.5));
                }
                if (snapshot.hasError) {
                  return _empty(
                    icon: Icons.error_outline,
                    title: 'Something went wrong',
                    subtitle: friendlyError(snapshot.error),
                  );
                }

                // Bucketing and ordering both live in event_history.dart so
                // they can be unit-tested away from Firestore.
                final docs = eventsForTab(
                  snapshot.data?.docs ?? [],
                  data: (d) => d.data(),
                  tab: _showPast ? EventTab.past : EventTab.upcoming,
                );

                if (docs.isEmpty) {
                  return _showPast
                      ? _empty(
                          icon: Icons.history_rounded,
                          title: 'No past events yet',
                          subtitle:
                              'Events you have run will be kept here once '
                              'their date has passed.',
                        )
                      : _empty(
                          icon: Icons.calendar_today_outlined,
                          title: 'No upcoming events',
                          subtitle:
                              'Create an event and athletes can register for it.',
                          actionLabel: 'New Event',
                        );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(docs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final ev = doc.data();

    // Same derivation as the home screen's event rows, shared with the tab
    // split so a row can never disagree with the bucket it was put in.
    final badge = badgeFor(ev);
    final label = badgeLabel(badge);
    final highlight = badge == EventBadge.upcoming;

    final date = asTimestamp(ev['eventDate'])?.toDate();
    final fmtDate =
        date != null ? DateFormat('MMM d, y · h:mm a').format(date) : 'Date TBD';
    final sport = asString(ev['sport']);
    final venue = asString(ev['venue']);
    final meta = [
      if (sport.isNotEmpty) sport,
      if (venue.isNotEmpty) venue,
      fmtDate,
    ].join(' · ');

    final playerCount = ev['playerCount'] is int ? ev['playerCount'] as int : 0;
    // 'No limit' events are created with maxPlayers left null.
    final maxPlayers = ev['maxPlayers'] is int ? ev['maxPlayers'] as int : null;
    final countLabel =
        maxPlayers != null ? '$playerCount/$maxPlayers' : '$playerCount';

    return GestureDetector(
      onTap: () =>
          Get.toNamed('/events/detail', arguments: {'eventId': doc.id}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border:
                Border.all(color: highlight ? AppTheme.accent : AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                  asString(ev['name']).isEmpty
                      ? 'Untitled Event'
                      : asString(ev['name']),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            _statusPill(label, highlight: highlight),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text(meta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.sub, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.groups_rounded, color: AppTheme.muted, size: 14),
            const SizedBox(width: 4),
            Text(countLabel,
                style: TextStyle(
                    color: AppTheme.sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }

  Widget _statusPill(String label, {required bool highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: highlight ? AppTheme.accentSurface : AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: highlight ? AppTheme.accent : AppTheme.border)),
      child: Text(label,
          style: TextStyle(
              color: highlight ? AppTheme.accentText : AppTheme.sub,
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.muted, size: 40),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Get.toNamed('/events/create'),
                child: Text(actionLabel),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Segmented Upcoming/Past toggle. A copy of `_EventTabToggle` from
/// home_screen.dart, relabelled — see the note on [MyEventsScreen].
class _EventTabToggle extends StatelessWidget {
  final bool showPast;
  final ValueChanged<bool> onChanged;
  const _EventTabToggle({required this.showPast, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildOption('Upcoming',
            selected: !showPast, onTap: () => onChanged(false)),
        _buildOption('Past', selected: showPast, onTap: () => onChanged(true)),
      ]),
    );
  }

  Widget _buildOption(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(17)),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.buttonFg : AppTheme.sub,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
