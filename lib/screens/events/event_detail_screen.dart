// lib/screens/events/event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/sport_icons.dart';
import '../../models/match_result.dart';
import '../../models/report.dart';
import '../../services/notification_service.dart';
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/draft_publish.dart';
import '../../utils/error_messages.dart';
import '../../utils/event_history.dart';
import '../../utils/event_recipients.dart';
import '../../utils/event_types.dart';
import '../../utils/firestore_helpers.dart';
import '../../utils/match_players.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../widgets/member_profiles.dart';
import '../../widgets/organizer_profile_parts.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/report_dialog.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  /// Read once, while this route is on top. `Get.arguments` always describes
  /// the top route, so reading it on every build would pick up the bracket's
  /// `{'tournamentId'}` while that is open above this screen, and a rebuild
  /// underneath would ask for `doc('')`.
  final String _eventId = (Get.arguments as Map?)?['eventId'] as String? ?? '';

  // Held here rather than created in build, so a rebuild doesn't
  // re-subscribe. The matches stream is only opened once a result exists.
  late final _eventStream = FirebaseFirestore.instance
      .collection('events').doc(_eventId).snapshots();
  late final _matchesStream = FirebaseFirestore.instance
      .collection('matches')
      .where('eventId', isEqualTo: _eventId)
      .snapshots();

  /// Blocks a second tap on Publish while the first is still writing, which
  /// would otherwise notify the whole roster twice.
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _eventStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Column(children: [
                _buildTopBar('Event'),
                Expanded(child: Center(child: Text('Event not found',
                    style: TextStyle(color: AppTheme.sub)))),
              ]);
            }
            return _buildContent(context,
                snapshot.data!.data() as Map<String, dynamic>);
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis)),
      if (action != null) ...[const SizedBox(width: 8), action],
    ]),
  );

  /// Files a complaint about this event into the admin console's Reports
  /// queue. Not offered to the event's own organizer, who can edit or cancel
  /// it directly instead.
  Widget _reportButton(BuildContext context, String eventName) =>
      GestureDetector(
        onTap: () => showReportDialog(
          context,
          targetType: Report.targetEvent,
          targetId: _eventId,
          targetLabel: eventName,
        ),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.flag_outlined,
              color: AppTheme.textPrimary, size: 17),
        ),
      );

  /// Hands [header] the event's recorded result, if any. Read from the match
  /// as soon as it's saved, not only once every player's stats are in and it
  /// is finalized, which left the score hidden until then.
  Widget _buildScoreboard(
      Map<String, dynamic> ev, Widget Function(MatchResult? result) header) {
    if (!hasResult(ev)) return header(null);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        final doc =
            latestMatch(snapshot.data?.docs ?? [], data: (d) => d.data());
        return header(
            doc == null ? null : MatchResult.fromMap(doc.id, doc.data()));
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> ev) {
    final name = ev['name'] as String? ?? 'Untitled Event';
    // Same badge as My Events and Home, so the three can't disagree.
    final isCancelled = ev['status'] == 'cancelled';
    final isDraft = ev['status'] == 'draft';
    final badge = badgeFor(ev);
    final statusLabel = badgeLabel(badge);
    final isNeutralStatus = badge != EventBadge.upcoming;
    // The same check Record Match makes. The button explains itself when the
    // game can't take a result yet, and is left out where it never will.
    final canRecord = canRecordResult(ev);
    final recordLabel = switch (badge) {
      EventBadge.awaitingResult => 'Record Match Results',
      EventBadge.completed => 'Result Recorded',
      EventBadge.upcoming => 'Results Open at Kickoff',
      EventBadge.draft || EventBadge.cancelled => null,
    };
    final sport = ev['sport'] as String? ?? '—';
    final venue = ev['venue'] as String? ?? '—';
    final venueAddress = ev['venueAddress'] as String? ?? '';
    final date = asTimestamp(ev['eventDate']);
    final fmtDate = date != null
        ? DateFormat('EEEE, MMM dd · h:mm a').format(date.toDate())
        : 'Date TBD';
    final playerCount = ev['playerCount'] as int? ?? 0;
    // 'No limit' events are created with maxPlayers left null.
    final maxPlayers = ev['maxPlayers'] as int?;
    final countLabel =
        maxPlayers != null ? '$playerCount/$maxPlayers' : '$playerCount';
    final players = (ev['players'] as List?)
        ?.map((p) => p as Map<String, dynamic>).toList() ?? [];
    // Null when blank, so every `?? 'Team A'` below also catches events
    // created from a coach with no team name, which stored an empty string
    // and rendered a side with no name at all.
    String? nonBlank(Object? v) =>
        (v as String? ?? '').trim().isEmpty ? null : (v as String).trim();
    final teamAName = nonBlank(ev['teamAName']);
    final teamBName = nonBlank(ev['teamBName']);
    final organizerId = ev['organizerId'] as String?;
    final isOrganizer = organizerId != null &&
        organizerId == FirebaseAuth.instance.currentUser?.uid;

    // This event is one matchup of a tournament bracket. It is owned by
    // that bracket: deleting or cancelling it would leave its slot pointing
    // at nothing and the tournament unable to move past that round, so the
    // destructive actions are replaced by a link back to the bracket. The
    // matching rule in firestore.rules is what actually enforces it.
    final tournamentId = ev['tournamentId'] as String?;
    final isBracketMatch = tournamentId != null;

    return Column(children: [
      _buildTopBar(name,
          action: isOrganizer ? null : _reportButton(context, name)),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isOrganizer && isDraft) ...[
              _buildDraftBanner(ev),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: isNeutralStatus
                            ? AppTheme.cardNested
                            : AppTheme.accentSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: isNeutralStatus
                                ? AppTheme.border
                                : AppTheme.accent)),
                    child: Text(statusLabel, style: TextStyle(
                        color: isNeutralStatus
                            ? AppTheme.muted
                            : AppTheme.accentText,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppTheme.cardNested,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border)),
                    child: Text(countLabel, style: TextStyle(
                        color: AppTheme.sub, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 12),
                _InfoRow(icon: sportIcon(sport), label: sport),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.location_on_outlined,
                    label: venueAddress.isNotEmpty
                        ? '$venue · $venueAddress' : venue),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.calendar_today_outlined, label: fmtDate),
              ]),
            ),
            // Who is running this event. Until this row, organizerId decided
            // which buttons were drawn and was never shown to anyone — an
            // athlete could be rostered into an event by a stranger they had
            // no way to look up.
            if (organizerId != null && organizerId.isNotEmpty) ...[
              const SizedBox(height: 12),
              OrganizerByline(organizerId: organizerId),
            ],
            const SizedBox(height: 20),
            _buildScoreboard(ev, (result) => _TeamVsTeamHeader(
              tuneUp: !countsTowardRankings(ev['eventType'] as String?),
              teamACoachId: ev['teamACoachId'] as String?,
              teamBCoachId: ev['teamBCoachId'] as String?,
              teamAName: teamAName ?? 'Team A',
              teamBName: teamBName ?? 'Team B',
              countA: players.where((p) => (p['team'] as String? ?? 'A') == 'A').length,
              countB: players.where((p) => (p['team'] as String? ?? 'A') == 'B').length,
              result: result,
            )),
            const SizedBox(height: 16),
            Row(children: [
              Text('ROSTER', style: TextStyle(
                  color: AppTheme.muted, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              // A draft keeps Edit Event after its date passes: picking a new
              // date is the only way it can still be published.
              if (isOrganizer &&
                  (isEventUpcoming(ev) || isDraft) &&
                  !isBracketMatch) ...[
                GestureDetector(
                  onTap: () => Get.toNamed('/events/edit',
                      arguments: {'eventId': _eventId}),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune_rounded, color: AppTheme.accent, size: 13),
                    SizedBox(width: 4),
                    Text('Edit Event', style: TextStyle(
                        color: AppTheme.accent, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 14),
              ],
              if (isOrganizer)
                GestureDetector(
                  onTap: () => Get.toNamed('/events/edit-teams',
                      arguments: {'eventId': _eventId}),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: AppTheme.accent, size: 13),
                    SizedBox(width: 4),
                    Text('Edit Teams', style: TextStyle(
                        color: AppTheme.accent, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),
            if (players.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(children: [
                  Icon(Icons.groups_outlined, color: AppTheme.muted, size: 28),
                  const SizedBox(height: 8),
                  Text('No players added yet',
                      style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                ]),
              )
            else ...[
              _buildPlayerGroup(context, teamAName ?? 'Team A',
                  players.where((p) => (p['team'] as String? ?? 'A') == 'A').toList()),
              _buildPlayerGroup(context, teamBName ?? 'Team B',
                  players.where((p) => (p['team'] as String? ?? 'A') == 'B').toList()),
            ],
            if (isBracketMatch) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Get.toNamed('/tournaments/detail',
                    arguments: {'tournamentId': tournamentId}),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    const Icon(Icons.account_tree_outlined,
                        color: AppTheme.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Part of a tournament bracket',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.muted, size: 20),
                  ]),
                ),
              ),
            ],
            if (isOrganizer) ...[
              if (recordLabel != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    // Straight to this game's lineup and score, not the list
                    // of every game waiting for a result.
                    onPressed: canRecord
                        ? () => Get.toNamed('/matches/record',
                            arguments: {'eventId': _eventId})
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        disabledBackgroundColor: AppTheme.cardNested,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(recordLabel, style: TextStyle(
                        color: canRecord ? AppTheme.buttonFg : AppTheme.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              if (!isCancelled && !isBracketMatch)
                _buildDangerZone(context, ev),
            ],
          ]),
        ),
      ),
    ]);
  }

  /// Shown to the organizer on their own draft. Saving a draft notified
  /// nobody, so this is the one place it can go live from; without it a draft
  /// could be edited or deleted but never announced.
  Widget _buildDraftBanner(Map<String, dynamic> ev) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note_rounded, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Draft · Only you can see this', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
            "Players and coaches haven't been told yet. Publish when you're "
            'ready to announce it.',
            style: TextStyle(color: AppTheme.sub, fontSize: 12, height: 1.4)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _publishing ? null : () => _publishDraft(ev),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.cardNested,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _publishing
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: AppTheme.accent, strokeWidth: 2))
                : const Text('Publish Event', style: TextStyle(
                    color: AppTheme.buttonFg, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  /// Takes a draft live: flips it to 'upcoming' and sends the roster and both
  /// coaches the same "upcoming game" notice a straight publish sends, in one
  /// batch so nobody is told about an event that failed to go live.
  Future<void> _publishDraft(Map<String, dynamic> ev) async {
    final problem = draftPublishProblem(ev);
    if (problem != null) {
      _snack("Can't Publish Yet", problem, isError: true);
      return;
    }

    final name = ev['name'] as String? ?? 'this event';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Publish $name?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            'Everyone on the roster and both coaches will be notified.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publish', style: TextStyle(
                color: AppTheme.accent, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _publishing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
          FirebaseFirestore.instance.collection('events').doc(_eventId),
          {'status': 'upcoming'});
      for (final notice in publishNotices(ev)) {
        await NotificationService.create(
          userId: notice.uid,
          type: 'event_added',
          title: notice.title,
          body: notice.body,
          relatedId: _eventId,
          writeBatch: batch,
        );
      }
      await batch.commit();
      // The event stream redraws the page as upcoming; no navigation needed.
      _snack('Event Published! 🏆', '$name is now live!');
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(title, msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.accentSurface,
      colorText: isError ? const Color(0xFFFF5C5C) : AppTheme.accentText,
      margin: const EdgeInsets.all(16), borderRadius: 12,
      duration: const Duration(seconds: 3));
  }

  Widget _buildPlayerGroup(
      BuildContext context, String teamLabel, List<Map<String, dynamic>> players) {
    if (players.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(teamLabel.toUpperCase(), style: TextStyle(
            color: AppTheme.muted, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        // An event's `players[]` froze each player's name at creation time and
        // never carried a photo at all, so the rows read the live user docs
        // and fall back to the stored snapshot only while those load.
        MemberProfilesBuilder(
          uids: players.map((p) => p['uid'] as String? ?? '').toList(),
          builder: (context, profiles) => Container(
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: players.asMap().entries.map((e) {
              final isLast = e.key == players.length - 1;
              final p = e.value;
              final uid = p['uid'] as String? ?? '';
              final position = p['position'] as String? ?? '';
              final identity = resolveMemberIdentity(profiles[uid],
                  fallbackName: p['fullName'] as String? ?? '');
              return Container(
                decoration: BoxDecoration(border: Border(
                    bottom: isLast
                        ? BorderSide.none
                        : BorderSide(color: AppTheme.border))),
                child: ListTile(
                  dense: true,
                  onTap: uid.isEmpty
                      ? null
                      : () => showAthleteProfileSheet(context, athleteId: uid),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: PlayerAvatar(
                      name: identity.name,
                      photoUrl: identity.photoUrl,
                      size: 36, fontSize: 12),
                  title: Text(identity.name, style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w600)),
                  subtitle: position.isNotEmpty
                      ? Text(position,
                          style: TextStyle(color: AppTheme.sub, fontSize: 11))
                      : null,
                ),
              );
            }).toList()),
          ),
        ),
      ]),
    );
  }

  /// Offers exactly one action based on how much history the event has:
  /// nothing recorded yet → hard delete is safe; a match exists but isn't
  /// finalized → soft cancel instead, so nothing gets orphaned; a finalized
  /// match already awarded points/ratings → neither is offered, since that
  /// history shouldn't be erasable.
  Widget _buildDangerZone(BuildContext context, Map<String, dynamic> ev) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('eventId', isEqualTo: _eventId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final matches = snapshot.data!.docs;
        final hasFinalized = matches.any((d) =>
            (d.data() as Map<String, dynamic>)['status'] == 'finalized');
        if (hasFinalized) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                "This game has recorded results and can't be cancelled or "
                'deleted.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          );
        }
        final hasMatches = matches.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => hasMatches
                  ? _confirmCancel(context, ev)
                  : _confirmDelete(context),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(hasMatches ? 'Cancel Event' : 'Delete Event',
                  style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete this event?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
            "This can't be undone. Nobody has recorded a match for it yet, "
            'so nothing else is affected.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseFirestore.instance
                  .collection('events').doc(_eventId).delete();
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(
                color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, Map<String, dynamic> ev) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel this event?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
            'Both coaches and everyone on the roster will be notified. '
            'The event stays '
            'visible in History, marked as cancelled.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _cancelEvent(ev);
            },
            child: const Text('Cancel Event', style: TextStyle(
                color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelEvent(Map<String, dynamic> ev) async {
    final batch = FirebaseFirestore.instance.batch();
    final eventRef = FirebaseFirestore.instance.collection('events').doc(_eventId);
    batch.update(eventRef, {'status': 'cancelled'});
    final name = ev['name'] as String? ?? 'The event';
    // Roster plus both head coaches — see event_recipients.dart.
    for (final uid in eventAudienceUids(ev)) {
      await NotificationService.create(
        userId: uid,
        type: 'event_cancelled',
        title: 'Game cancelled',
        body: '$name has been cancelled by the organizer.',
        relatedId: _eventId,
        writeBatch: batch,
      );
    }
    await batch.commit();
    Get.back();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.muted, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(
        color: AppTheme.sub, fontSize: 13), overflow: TextOverflow.ellipsis)),
  ]);
}

/// The two teams facing off, each with its coach-set logo (or a generic
/// placeholder if this side wasn't built from a picked coach team) and
/// player count. Once a result is recorded, its score replaces "VS".
class _TeamVsTeamHeader extends StatelessWidget {
  final String? teamACoachId;
  final String? teamBCoachId;
  final String teamAName;
  final String teamBName;
  final int countA;
  final int countB;
  final MatchResult? result;

  /// A practice or exhibition game, which says so instead of promising a
  /// rating update.
  final bool tuneUp;

  const _TeamVsTeamHeader({
    this.tuneUp = false,
    required this.teamACoachId,
    required this.teamBCoachId,
    required this.teamAName,
    required this.teamBName,
    required this.countA,
    required this.countB,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _TeamBlock(coachId: teamACoachId, name: teamAName, count: countA)),
          if (result == null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text('VS', style: TextStyle(
                  color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w800)),
            )
          else
            _buildScore(result),
          Expanded(
              child: _TeamBlock(coachId: teamBCoachId, name: teamBName, count: countB)),
        ]),
        if (tuneUp) ...[
          const SizedBox(height: 12),
          Text("Tune-up: doesn't change Elo or points.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 11)),
        ]
        // The score is final once recorded; ratings wait for Add Stats.
        else if (result != null && !result.isFinalized) ...[
          const SizedBox(height: 12),
          Text("Ratings update once every player's stats are in.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 11)),
        ],
      ]),
    );
  }

  /// "FINAL" over the score, the winner's number in gold. Sized to sit level
  /// with the 56dp team logos either side.
  Widget _buildScore(MatchResult result) {
    TextStyle scoreStyle(bool won) => TextStyle(
        color: won ? AppTheme.accentText : AppTheme.sub,
        fontSize: 24, fontWeight: FontWeight.w900);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Column(children: [
        Text('FINAL', style: TextStyle(
            color: AppTheme.muted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${result.scoreA}', style: scoreStyle(result.winner == 'A')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('–', style: TextStyle(
                color: AppTheme.muted, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Text('${result.scoreB}', style: scoreStyle(result.winner == 'B')),
        ]),
      ]),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String? coachId;
  final String name;
  final int count;

  const _TeamBlock({required this.coachId, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildLogo(),
      const SizedBox(height: 8),
      Text(name, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text('$count player${count == 1 ? '' : 's'}',
          style: TextStyle(color: AppTheme.sub, fontSize: 11)),
    ]);
  }

  Widget _buildLogo() {
    final id = coachId;
    if (id == null || id.isEmpty) {
      return Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Icon(Icons.shield_outlined, color: AppTheme.muted, size: 26),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
      builder: (context, snapshot) {
        final logoUrl =
            (snapshot.data?.data() as Map<String, dynamic>?)?['teamLogoUrl'] as String?;
        return Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: AppTheme.cardNested,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: logoUrl != null && logoUrl.isNotEmpty
                ? Image.network(logoUrl, fit: BoxFit.cover, width: 56, height: 56,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.shield_outlined, color: AppTheme.muted, size: 26))
                : Icon(Icons.shield_outlined, color: AppTheme.muted, size: 26),
          ),
        );
      },
    );
  }
}
