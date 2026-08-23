// lib/screens/events/event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/match_result.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';

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
            return _buildContent(
                snapshot.data!.data() as Map<String, dynamic>);
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(String title) => Padding(
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
    ]),
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

  Widget _buildContent(Map<String, dynamic> ev) {
    final name = ev['name'] as String? ?? 'Untitled Event';
    // The raw `status` field is only ever 'draft' or 'upcoming' and never
    // updates itself once a game happens, so the displayed label is derived
    // from the real eventDate instead — see isEventUpcoming() in
    // firestore_helpers.dart.
    final isDraft = ev['status'] == 'draft';
    final isCompleted = !isDraft && !isEventUpcoming(ev);
    final statusLabel = isDraft ? 'DRAFT' : (isCompleted ? 'COMPLETED' : 'UPCOMING');
    final isNeutralStatus = isDraft || isCompleted;
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

    return Column(children: [
      _buildTopBar(name),
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
            const SizedBox(height: 20),
            _buildMatchResults(teamAName, teamBName),
            Row(children: [
              Text('ROSTER', style: TextStyle(
                  color: AppTheme.muted, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              if (isOrganizer)
                GestureDetector(
                  onTap: () => Get.toNamed('/events/edit-teams',
                      arguments: {'eventId': _eventId}),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: AppTheme.accent, size: 13),
                    const SizedBox(width: 4),
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
            else
              Container(
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(children: players.asMap().entries.map((e) {
                  final isLast = e.key == players.length - 1;
                  final p = e.value;
                  final fullName = p['fullName'] as String? ?? '';
                  final position = p['position'] as String? ?? '';
                  final team = p['team'] as String?;
                  String? teamLabel;
                  if (team == 'A') teamLabel = teamAName;
                  if (team == 'B') teamLabel = teamBName;
                  final subtitleText = [
                    if (position.isNotEmpty) position,
                    if (teamLabel != null && teamLabel.isNotEmpty) teamLabel,
                  ].join(' · ');
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
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
                      subtitle: subtitleText.isNotEmpty
                          ? Text(subtitleText,
                              style: TextStyle(color: AppTheme.sub, fontSize: 11))
                          : null,
                    ),
                  );
                }).toList()),
              ),
            if (isOrganizer) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed('/matches/record'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Record Match Results', style: TextStyle(
                      color: AppTheme.buttonFg, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
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
        Icon(Icons.emoji_events_rounded, color: AppTheme.accent, size: 14),
      ],
    ]);
  }
}
