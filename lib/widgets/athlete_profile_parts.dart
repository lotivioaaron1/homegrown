// lib/widgets/athlete_profile_parts.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/query_limits.dart';
import '../theme/app_theme.dart';
import '../utils/stat_scoring.dart';

/// The pieces an athlete's profile is built from, shared by the quick-peek
/// bottom sheet ([showAthleteProfileSheet]) and the full-screen view
/// ([AthleteProfileViewScreen]).
///
/// They were private to the sheet until the full-screen view needed the same
/// stat boxes and the same per-sport averages. Extracting them keeps the two
/// surfaces showing identical numbers in an identical style — the alternative
/// is the drift that made the shared sheet necessary in the first place.

// ─────────────────────────────────────────────
// Per-stat-category averages
// ─────────────────────────────────────────────

/// Answers "what is this player good at" (rebounding, steals, etc.) rather
/// than one comparative number, which is what Rating answers.
class AthleteStatAverages extends StatelessWidget {
  final String athleteId;
  const AthleteStatAverages({super.key, required this.athleteId});

  @override
  Widget build(BuildContext context) {
    if (athleteId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      // Averaged over the most recent games rather than every game ever
      // recorded, so one prolific athlete can't turn opening a profile into an
      // unbounded read. Deterministic because it is ordered, not arbitrary.
      future: FirebaseFirestore.instance
          .collection('stats')
          .where('athleteId', isEqualTo: athleteId)
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
            style: TextStyle(
                color: AppTheme.sub,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: avgs.entries
              .map((e) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppTheme.cardNested,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key,
                            style:
                                TextStyle(color: AppTheme.muted, fontSize: 9)),
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

// ─────────────────────────────────────────────
// Small shared building blocks
// ─────────────────────────────────────────────

/// One cell of the headline figure row (Total Pts / Experience / Height /
/// Weight). Expands to share the row evenly with its siblings.
class ProfileStatBox extends StatelessWidget {
  final String value, label;
  final bool isAccent;
  const ProfileStatBox(
      {super.key,
      required this.value,
      required this.label,
      this.isAccent = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isAccent ? AppTheme.accentSurface : AppTheme.cardNested,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: isAccent ? AppTheme.accent : AppTheme.border)),
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

/// A labelled detail line — Sport, Position, Barangay, Experience.
class ProfileInfoRow extends StatelessWidget {
  final String label, value;
  const ProfileInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: AppTheme.muted, fontSize: 12))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
      ]);
}
