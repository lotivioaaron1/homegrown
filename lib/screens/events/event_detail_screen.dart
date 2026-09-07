// lib/screens/events/event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/match_result.dart';
import '../../models/report.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../widgets/organizer_profile_parts.dart';
import '../../widgets/report_dialog.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key});

  String get _eventId => (Get.arguments as Map?)?['eventId'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(_eventId).snapshots(),
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

  Widget _buildMatchResults(String? teamAName, String? teamBName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('eventId', isEqualTo: _eventId)
          .where('status', isEqualTo: 'finalized')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final matches = docs
            .map((d) => MatchResult.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RESULT', style: TextStyle(
                color: AppTheme.muted, fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...matches.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MatchResultCard(
                    match: m, teamAName: teamAName, teamBName: teamBName))),
          ]),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> ev) {
    final name = ev['name'] as String? ?? 'Untitled Event';
    // The raw `status` field is only ever 'draft' or 'upcoming' and never
    // updates itself once a game happens, so the displayed label is derived
    // from the real eventDate instead — see isEventUpcoming() in
    // firestore_helpers.dart.
    final isCancelled = ev['status'] == 'cancelled';
    final isDraft = ev['status'] == 'draft';
    final isCompleted = !isCancelled && !isDraft && !isEventUpcoming(ev);
    final statusLabel = isCancelled ? 'CANCELLED'
        : isDraft ? 'DRAFT' : (isCompleted ? 'COMPLETED' : 'UPCOMING');
    final isNeutralStatus = isCancelled || isDraft || isCompleted;
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
    final teamAName = ev['teamAName'] as String?;
    final teamBName = ev['teamBName'] as String?;
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
                _InfoRow(icon: Icons.sports_basketball_outlined, label: sport),
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
            _buildMatchResults(teamAName, teamBName),
            _TeamVsTeamHeader(
              teamACoachId: ev['teamACoachId'] as String?,
              teamBCoachId: ev['teamBCoachId'] as String?,
              teamAName: teamAName ?? 'Team A',
              teamBName: teamBName ?? 'Team B',
              countA: players.where((p) => (p['team'] as String? ?? 'A') == 'A').length,
              countB: players.where((p) => (p['team'] as String? ?? 'A') == 'B').length,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('ROSTER', style: TextStyle(
                  color: AppTheme.muted, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              if (isOrganizer && isEventUpcoming(ev) && !isBracketMatch) ...[
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed('/matches/record',
                      arguments: isBracketMatch ? {'eventId': _eventId} : null),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Record Match Results', style: TextStyle(
                      color: AppTheme.buttonFg, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                ),
              ),
              if (!isCancelled && !isBracketMatch)
                _buildDangerZone(context, ev),
            ],
          ]),
        ),
      ),
    ]);
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
        Container(
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: players.asMap().entries.map((e) {
            final isLast = e.key == players.length - 1;
            final p = e.value;
            final uid = p['uid'] as String? ?? '';
            final fullName = p['fullName'] as String? ?? '';
            final position = p['position'] as String? ?? '';
            final initials = fullName.trim().split(' ')
                .where((s) => s.isNotEmpty).take(2)
                .map((s) => s[0]).join().toUpperCase();
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
                leading: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.accent, AppTheme.accent2]),
                    shape: BoxShape.circle),
                  child: Center(child: Text(initials, style: const TextStyle(
                      color: AppTheme.buttonFg, fontSize: 12,
                      fontWeight: FontWeight.w800))),
                ),
                title: Text(fullName, style: TextStyle(
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
            'Everyone on the roster will be notified. The event stays '
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
    final playerUids = List<String>.from(ev['playerUids'] as List? ?? []);
    for (final uid in playerUids) {
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

/// One finalized match's score, with the winning side highlighted. An event
/// can technically have more than one recorded match, so the caller renders
/// one of these per finalized match rather than assuming a single result.
class _MatchResultCard extends StatelessWidget {
  final MatchResult match;
  final String? teamAName;
  final String? teamBName;
  const _MatchResultCard({
    required this.match,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Expanded(
          child: _TeamScore(
              name: teamAName ?? 'Team A',
              score: match.scoreA,
              isWinner: match.winner == 'A'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('vs', style: TextStyle(color: AppTheme.muted,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: _TeamScore(
              name: teamBName ?? 'Team B',
              score: match.scoreB,
              isWinner: match.winner == 'B'),
        ),
      ]),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int score;
  final bool isWinner;
  const _TeamScore({
    required this.name,
    required this.score,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: isWinner ? AppTheme.textPrimary : AppTheme.sub,
              fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('$score', style: TextStyle(
          color: isWinner ? AppTheme.accent : AppTheme.muted,
          fontSize: 24, fontWeight: FontWeight.w900)),
      if (isWinner) ...[
        const SizedBox(height: 4),
        const Icon(Icons.emoji_events_rounded, color: AppTheme.accent, size: 14),
      ],
    ]);
  }
}

/// The two teams facing off, each with its coach-set logo (or a generic
/// placeholder if this side wasn't built from a picked coach team) and
/// player count.
class _TeamVsTeamHeader extends StatelessWidget {
  final String? teamACoachId;
  final String? teamBCoachId;
  final String teamAName;
  final String teamBName;
  final int countA;
  final int countB;

  const _TeamVsTeamHeader({
    required this.teamACoachId,
    required this.teamBCoachId,
    required this.teamAName,
    required this.teamBName,
    required this.countA,
    required this.countB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: _TeamBlock(coachId: teamACoachId, name: teamAName, count: countA)),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text('VS', style: TextStyle(
              color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        Expanded(
            child: _TeamBlock(coachId: teamBCoachId, name: teamBName, count: countB)),
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
