// lib/widgets/athlete_profile_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants/query_limits.dart';
import '../theme/app_theme.dart';
import '../utils/stat_scoring.dart';

/// Shared read-only athlete profile bottom sheet — avatar, stat boxes,
/// per-category stat averages, and bio. Leaderboard, Scout, My Team, and
/// event rosters all used to carry their own nearly-identical copy of this;
/// this is the one implementation they share instead.
///
/// [trailingActionBuilder], if given, is called with the fetched athlete
/// data to build a caller-specific action shown above the Close button —
/// e.g. Scout's "Invite to Team" button, which Leaderboard/My Team/event
/// rosters don't show.
void showAthleteProfileSheet(
  BuildContext context, {
  required String athleteId,
  Widget Function(BuildContext context, Map<String, dynamic> athlete)?
      trailingActionBuilder,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(athleteId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2));
          }
          final athlete = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          return _AthleteProfileContent(
            scrollController: ctrl,
            athleteId: athleteId,
            athlete: athlete,
            trailingActionBuilder: trailingActionBuilder,
          );
        },
      ),
    ),
  );
}

class _AthleteProfileContent extends StatelessWidget {
  final ScrollController scrollController;
  final String athleteId;
  final Map<String, dynamic> athlete;
  final Widget Function(BuildContext context, Map<String, dynamic> athlete)?
      trailingActionBuilder;

  const _AthleteProfileContent({
    required this.scrollController,
    required this.athleteId,
    required this.athlete,
    required this.trailingActionBuilder,
  });

  int _toInt(dynamic v) => v is int ? v : (v is double ? v.toInt() : 0);

  @override
  Widget build(BuildContext context) {
    final firstName = athlete['firstName'] as String? ?? '';
    final lastName = athlete['lastName'] as String? ?? '';
    final position = athlete['position'] as String? ?? '—';
    final barangay = athlete['barangay'] as String? ?? '—';
    final years = athlete['yearsOfPlaying'] as String? ?? '—';
    final height = athlete['heightCm']?.toString() ?? '—';
    final weight = athlete['weightKg']?.toString() ?? '—';
    final bio = athlete['bio'] as String? ?? '';
    final sports = (athlete['primarySports'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '—';
    final isOpen = athlete['openToRecruitment'] as bool? ?? false;
    final pts = _toInt(athlete['points']);
    final photoUrl = athlete['photoUrl'] as String?;
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Center(
              child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 2.5)),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(photoUrl,
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: AppTheme.buttonFg,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900))))
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: AppTheme.buttonFg,
                                fontSize: 22,
                                fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 10),
            Text('$firstName $lastName',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('$position · $barangay',
                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: isOpen ? AppTheme.successSurface : AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isOpen ? AppTheme.successText : AppTheme.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isOpen ? AppTheme.successText : AppTheme.muted, size: 14),
                  const SizedBox(width: 6),
                  Text(isOpen ? 'Open to Recruitment' : 'Not Available',
                      style: TextStyle(
                          color: isOpen ? AppTheme.successText : AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ])),
          ])),
          const SizedBox(height: 20),
          Row(children: [
            _StatBox(value: '$pts', label: 'Total Pts', isAccent: true),
            const SizedBox(width: 8),
            _StatBox(value: years, label: 'Experience'),
            const SizedBox(width: 8),
            _StatBox(value: '${height}cm', label: 'Height'),
            const SizedBox(width: 8),
            _StatBox(value: '${weight}kg', label: 'Weight'),
          ]),
          const SizedBox(height: 16),
          _buildStatAverages(athleteId),
          const SizedBox(height: 16),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          _InfoRow(label: 'Sport', value: sports),
          const SizedBox(height: 8),
          _InfoRow(label: 'Position', value: position),
          const SizedBox(height: 8),
          _InfoRow(label: 'Barangay', value: barangay),
          const SizedBox(height: 8),
          _InfoRow(label: 'Experience', value: years),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Bio',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Text(bio,
                    style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5))),
          ],
          const SizedBox(height: 24),
          if (trailingActionBuilder != null) ...[
            trailingActionBuilder!(context, athlete),
            const SizedBox(height: 10),
          ],
          SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: Text('Close',
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }

  // ── Per-stat-category averages ────────────
  // Answers "what is this player good at" (rebounding, steals, etc.)
  // rather than one comparative number, which is what Rating answers.
  Widget _buildStatAverages(String uid) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      // Averaged over the most recent games rather than every game ever
      // recorded, so one prolific athlete can't turn opening a profile into an
      // unbounded read. Deterministic because it is ordered, not arbitrary.
      future: FirebaseFirestore.instance
          .collection('stats')
          .where('athleteId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(kMaxListQuery)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 32,
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2))));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final bySport = <String, List<Map<String, dynamic>>>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final sport = data['sport'] as String? ?? '';
          final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
          bySport.putIfAbsent(sport, () => []).add(stats);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Averages',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...bySport.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SportAverages(sport: e.key, games: e.value),
                )),
          ],
        );
      },
    );
  }
}

class _SportAverages extends StatelessWidget {
  final String sport;
  final List<Map<String, dynamic>> games;
  const _SportAverages({required this.sport, required this.games});

  String _format(String label, double value) {
    final formatted = formatStatAverage(value);
    return label == 'Win Rate %' ? '$formatted%' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final avgs = averageStats(sport, games);
    if (avgs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$sport · ${games.length} game${games.length == 1 ? '' : 's'}',
            style:
                TextStyle(color: AppTheme.sub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: avgs.entries
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppTheme.cardNested,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: TextStyle(color: AppTheme.muted, fontSize: 9)),
                        Text(_format(e.key, e.value),
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final bool isAccent;
  const _StatBox({required this.value, required this.label, this.isAccent = false});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isAccent ? AppTheme.accentSurface : AppTheme.cardNested,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isAccent ? AppTheme.accent : AppTheme.border)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: isAccent ? AppTheme.accentText : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: AppTheme.muted, fontSize: 9),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: AppTheme.muted, fontSize: 12))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
      ]);
}
