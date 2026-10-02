// lib/widgets/championships.dart
//
// The three places a tournament title is shown off beyond its own page:
// a shelf on profiles, a row on team pages, and a spotlight on Home. Each
// reads the finished tournaments once and picks out its titles with
// lib/utils/championships.dart, and each renders nothing at all when there
// are none, so a screen without titles looks exactly as it did before.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../theme/app_theme.dart';
import '../utils/championships.dart';

void _openChampionship(Tournament t) =>
    Get.toNamed('/tournaments/champion', arguments: {'tournamentId': t.id});

String _monthYear(Tournament t) =>
    t.completedAt == null ? '' : DateFormat('MMM y').format(t.completedAt!);

/// Rebuilds [builder] with every finished tournament. The stream is held in
/// State, so a parent rebuilding doesn't re-subscribe it.
class _CompletedTournaments extends StatefulWidget {
  final Widget Function(List<Tournament> tournaments) builder;
  const _CompletedTournaments({required this.builder});

  @override
  State<_CompletedTournaments> createState() => _CompletedTournamentsState();
}

class _CompletedTournamentsState extends State<_CompletedTournaments> {
  late final _stream = TournamentService.completedStream();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Tournament>>(
        stream: _stream,
        builder: (context, snap) => widget.builder(snap.data ?? const []),
      );
}

/// "Championships" on an athlete's or coach's profile: one card per title,
/// newest first, each opening its championship page.
class ChampionshipShelf extends StatelessWidget {
  final String uid;

  /// Space around the shelf, applied only when there is a shelf to show.
  final EdgeInsets padding;

  const ChampionshipShelf({
    super.key,
    required this.uid,
    this.padding = const EdgeInsets.only(top: 18),
  });

  @override
  Widget build(BuildContext context) {
    return _CompletedTournaments(builder: (tournaments) {
      final titles = titlesFor(tournaments, uid);
      if (titles.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.emoji_events_rounded,
                color: AppTheme.accentText, size: 15),
            const SizedBox(width: 6),
            Text('CHAMPIONSHIPS · ${titles.length}',
                style: TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          for (final t in titles) _TitleCard(t),
        ]),
      );
    });
  }
}

class _TitleCard extends StatelessWidget {
  final Tournament t;
  const _TitleCard(this.t);

  @override
  Widget build(BuildContext context) {
    final details = [
      t.sport,
      if ((t.championTeamName ?? '').isNotEmpty) t.championTeamName!,
      if (_monthYear(t).isNotEmpty) _monthYear(t),
    ].join(' · ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openChampionship(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events_rounded,
                color: AppTheme.accentText, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.name} Champion',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(details,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }
}

/// "Tournaments" on a coach's own profile: the team's record in one line,
/// then a card per title. Unlike the shelf it always shows, so a coach can
/// see their tournaments counted before the first win.
class TournamentRecord extends StatefulWidget {
  final String coachId;
  const TournamentRecord({super.key, required this.coachId});

  @override
  State<TournamentRecord> createState() => _TournamentRecordState();
}

class _TournamentRecordState extends State<TournamentRecord> {
  late final _stream = TournamentService.completedStream();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Tournament>>(
        stream: _stream,
        builder: (context, snap) {
          // Nothing until the first read lands: an empty list here would
          // briefly claim the team has never finished a tournament.
          if (!snap.hasData) return const SizedBox.shrink();
          final tournaments = snap.data!;
          final played = tournamentsPlayed(tournaments, widget.coachId);
          final titles = teamTitles(tournaments, widget.coachId);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournamentRecordLabel(played.length, titles.length),
                    style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                if (titles.isNotEmpty) const SizedBox(height: 10),
                for (final t in titles) _TitleCard(t),
              ]);
        },
      );
}

/// A team's titles on its team page: "2× Champion" and a chip per title
/// (the newest three), each opening its championship page.
class TeamTitlesRow extends StatelessWidget {
  final String coachId;

  /// Space around the row, applied only when there is a row to show.
  final EdgeInsets padding;

  const TeamTitlesRow({
    super.key,
    required this.coachId,
    this.padding = const EdgeInsets.only(top: 12),
  });

  @override
  Widget build(BuildContext context) {
    return _CompletedTournaments(builder: (tournaments) {
      final titles = teamTitles(tournaments, coachId);
      if (titles.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.emoji_events_rounded,
                  color: AppTheme.accentText, size: 18),
              const SizedBox(width: 8),
              Text(titleCountLabel(titles.length),
                  style: TextStyle(
                      color: AppTheme.accentText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in titles.take(3))
                GestureDetector(
                  onTap: () => _openChampionship(t),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accent)),
                    child: Text(
                        [t.name, _monthYear(t)]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ]),
        ),
      );
    });
  }
}

/// "New champions" on Home, for everyone: the tournaments won in the last
/// week (at most two), each opening its championship page.
class ChampionsSpotlight extends StatelessWidget {
  /// Space around the spotlight, applied only when there is one to show.
  final EdgeInsets padding;

  /// An organizer whose own tournaments are left out, as their Home already
  /// shows those champions.
  final String? exceptOrganizer;

  const ChampionsSpotlight({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
    this.exceptOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    return _CompletedTournaments(builder: (tournaments) {
      final recent = recentChampions(tournaments,
              exceptOrganizer: exceptOrganizer)
          .take(2)
          .toList();
      if (recent.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: Column(children: [for (final t in recent) _spotlight(t)]),
      );
    });
  }

  Widget _spotlight(Tournament t) {
    final when = t.completedAt == null
        ? ''
        : ' · ${DateFormat('MMM d').format(t.completedAt!)}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openChampionship(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppTheme.accent, shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppTheme.buttonFg, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEW CHAMPIONS',
                      style: TextStyle(
                          color: AppTheme.accentText,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${t.championTeamName ?? 'A team'} won ${t.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${t.sport}$when',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.accentText, size: 22),
        ]),
      ),
    );
  }
}
