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
import '../../utils/event_sections.dart';
import '../../utils/event_sport_filter.dart';
import '../../utils/firestore_helpers.dart';

const _kRadius = 16.0;

/// The organizer's own events, split into Upcoming and Past. Past is grouped
/// by status, with games still awaiting a result first, since those are the
/// organizer's to-do list; each of those cards opens Record Match directly.
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

  /// The sport chip picked, or null for All.
  String? _sport;

  /// The sports on the organizer's profile, so a sport with nothing scheduled
  /// yet still gets a chip.
  List<String> _organized = const [];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadOrganizedSports(uid);

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

  /// Read once, the same way Create Event reads it. Until it arrives, or if
  /// it can't be read, the chips come from the events alone.
  Future<void> _loadOrganizedSports(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final sports = (doc.data()?['sportsOrganized'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (mounted) setState(() => _organized = sports);
    } catch (_) {
      // Keep the event-derived chips; the list itself is unaffected.
    }
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
          // The toggle sits inside the stream so the Past option can show how
          // many games are waiting for a result.
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                final everything = snapshot.data?.docs ?? [];
                final sports = sportFilterOptions(
                  organized: _organized,
                  eventSports:
                      everything.map((d) => asString(d.data()['sport'])),
                );
                // Chips only when there is more than one sport to pick from.
                final showChips = sports.length > 1;
                final sport = sports.contains(_sport) ? _sport : null;
                // The tabs, the Past groups and the count all follow the chip.
                final all = eventsForSport(everything,
                    data: (d) => d.data(), sport: sport);
                return Column(children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, showChips ? 8 : 14),
                    child: _EventTabToggle(
                      showPast: _showPast,
                      awaitingCount:
                          awaitingResultCount(all, data: (d) => d.data()),
                      onChanged: (value) => setState(() => _showPast = value),
                    ),
                  ),
                  if (showChips) _sportChips(sports, sport, everything),
                  Expanded(child: _buildList(snapshot, all, sport)),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// All, then one chip per sport. A sport with games awaiting a result gets
  /// a gold dot, so a filtered view still hints at unrecorded games elsewhere.
  Widget _sportChips(List<String> sports, String? selected,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> everything) {
    bool hasAwaiting(String sport) =>
        awaitingResultCount(
            eventsForSport(everything, data: (d) => d.data(), sport: sport),
            data: (d) => d.data()) >
        0;

    // Pinned left, in line with the toggle and cards; on its own the scroll
    // view sizes to its chips and the column centres it.
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
        child: Row(children: [
          _sportChip('All',
              selected: selected == null,
              awaiting: false,
              onTap: () => setState(() => _sport = null)),
          for (final sport in sports)
            _sportChip(sport,
                selected: selected == sport,
                awaiting: hasAwaiting(sport),
                onTap: () => setState(() => _sport = sport)),
        ]),
      ),
    );
  }

  /// Styled like the leaderboard's sport chips. The 36dp chip is padded out
  /// to a 44dp tap area.
  Widget _sportChip(String label,
      {required bool selected,
      required bool awaiting,
      required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? AppTheme.accentSurface : AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppTheme.accent : AppTheme.border,
                  width: selected ? 2 : 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: selected ? AppTheme.accentText : AppTheme.muted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            if (awaiting) ...[
              const SizedBox(width: 6),
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildList(
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
      String? sport) {
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

    // Bucketing, grouping and ordering live in event_history.dart and
    // event_sections.dart so they can be unit-tested away from Firestore.
    // [all] is already narrowed to the chosen sport.
    final sportWord = sport == null ? '' : '$sport ';

    if (_showPast) {
      final sections = pastSections(all, data: (d) => d.data());
      if (sections.isEmpty) {
        return _empty(
          icon: Icons.history_rounded,
          title: 'No past ${sportWord}events yet',
          subtitle: 'Events you have run will be kept here once '
              'their date has passed.',
        );
      }
      // The group heading names the status, so the cards drop their pill.
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _sectionHeader(sections[i]),
            for (final doc in sections[i].events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(doc, showPill: false),
              ),
          ],
        ],
      );
    }

    final docs =
        eventsForTab(all, data: (d) => d.data(), tab: EventTab.upcoming);
    if (docs.isEmpty) {
      return _empty(
        icon: Icons.calendar_today_outlined,
        title: 'No upcoming ${sportWord}events',
        subtitle: 'Create an event and pick a team for each side. '
            'Their players are told once you publish.',
        actionLabel: 'New Event',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _card(docs[i]),
    );
  }

  /// A Past group's heading. Awaiting Result also says why it matters, since
  /// it is the one group the organizer has to act on.
  Widget _sectionHeader(
      EventSection<QueryDocumentSnapshot<Map<String, dynamic>>> section) {
    final awaiting = section.badge == EventBadge.awaitingResult;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (awaiting) ...[
            Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppTheme.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Text('${badgeLabel(section.badge)} · ${section.events.length}',
              style: TextStyle(
                  color: awaiting ? AppTheme.textPrimary : AppTheme.muted,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800)),
        ]),
        if (awaiting) ...[
          const SizedBox(height: 4),
          Text(
              "Record each score, then add every player's stats so their "
              'ratings update.',
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      {bool showPill = true}) {
    final ev = doc.data();

    // Same derivation as the home screen's event rows, shared with the tab
    // split so a row can never disagree with the bucket it was put in.
    final badge = badgeFor(ev);
    final label = badgeLabel(badge);
    // Awaiting-result games are highlighted too: they're the organizer's
    // to-do, not history.
    final highlight = badge == EventBadge.upcoming ||
        badge == EventBadge.awaitingResult;
    // The same check Record Match makes, so the button only appears on a game
    // it will accept.
    final canRecord = canRecordResult(ev);
    // A draft gets a way back in, since its page is where it gets published.
    // Covers a stale draft on the Past tab too, which needs a new date first.
    final isDraft = badge == EventBadge.draft;
    final hasButton = canRecord || isDraft;

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
        // The card button's padded tap area fills the top gap instead.
        padding: hasButton
            ? const EdgeInsets.fromLTRB(14, 8, 14, 14)
            : const EdgeInsets.all(14),
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
            if (showPill && !isDraft) ...[
              const SizedBox(width: 8),
              _statusPill(label, highlight: highlight),
            ],
            if (canRecord)
              _cardButton('Record',
                  () => Get.toNamed('/matches/record',
                      arguments: {'eventId': doc.id})),
            if (isDraft)
              _cardButton('Continue',
                  () => Get.toNamed('/events/detail',
                      arguments: {'eventId': doc.id})),
          ]),
          SizedBox(height: hasButton ? 0 : 6),
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

  /// A card's one action: Record on a game awaiting its result, Continue on a
  /// draft. The 32dp button is padded out to a 44dp tap area, so a near miss
  /// still lands on it rather than the card.
  Widget _cardButton(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.accentText, size: 16),
          ]),
        ),
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

/// Full-width Upcoming/Past switch, the screen's main control. It started as
/// a copy of `_EventTabToggle` in home_screen.dart (see the note on
/// [MyEventsScreen]) and was widened here so it reads above the sport chips
/// and each half is a 44dp tap target.
class _EventTabToggle extends StatelessWidget {
  final bool showPast;

  /// Games played but not yet recorded; shown on the Past option when any.
  final int awaitingCount;
  final ValueChanged<bool> onChanged;
  const _EventTabToggle({
    required this.showPast,
    required this.awaitingCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Expanded(
          child: _buildOption('Upcoming',
              selected: !showPast, onTap: () => onChanged(false)),
        ),
        Expanded(
          child: _buildOption(
              awaitingCount > 0 ? 'Past · $awaitingCount' : 'Past',
              selected: showPast,
              onTap: () => onChanged(true)),
        ),
      ]),
    );
  }

  /// The whole half is tappable, including the inset around the pill.
  Widget _buildOption(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? AppTheme.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(18)),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppTheme.buttonFg : AppTheme.sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
