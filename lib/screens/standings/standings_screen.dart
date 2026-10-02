// lib/screens/standings/standings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/standings_service.dart';
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/team_standings.dart';
import '../../widgets/coach_profile_sheet.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/standings_table.dart';

/// The same sports, in the same order, as the Leaderboard's filter.
const List<String> _kSports = ['Basketball', 'Volleyball', 'Badminton'];

const Map<String, String> _kSportEmoji = {
  'Basketball': '🏀',
  'Volleyball': '🏐',
  'Badminton': '🏸',
};

/// One season's table for one sport: every coach's team that played an
/// official game, ranked by record. Opened from the Leaderboard's Teams
/// button, which passes the sport it was showing as `Get.arguments`.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _Board {
  /// Which sport and season this board is for, so a refresh can keep showing
  /// it while the same table reloads, but a sport switch never shows the old
  /// sport's table under the new chip.
  final String key;

  final List<TeamStanding> table;
  final List<int> ranks;

  /// Each coach's live `users` doc, for the team's current name and logo.
  final Map<String, Map<String, dynamic>> coaches;

  const _Board(this.key, this.table, this.ranks, this.coaches);
}

class _StandingsScreenState extends State<StandingsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final List<int> _seasons = seasonsSince(kFirstSeason, DateTime.now());

  late String _sport;
  late int _season;
  late Future<_Board> _board;

  /// The coaches whose teams count as the viewer's: their own uid (a coach's
  /// team is keyed by the coach) plus the coaches of any team they play for.
  /// Empty for an organizer. Only drives the highlight, so a failed read
  /// leaves it empty rather than showing an error.
  Set<String> _myTeams = {};

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    _sport = arg is String && _kSports.contains(arg) ? arg : _kSports.first;
    _season = _seasons.first;
    _board = _load();
    _loadMyTeams();
  }

  String get _boardKey => '$_sport/$_season';

  Future<_Board> _load() async {
    final key = _boardKey;
    final games = await StandingsService.fetchSeasonGames(_sport, _season);
    final table = computeStandings(games);
    final coaches =
        await TeamService.fetchMemberProfiles(table.map((s) => s.coachId));
    return _Board(key, table, standingRanks(table), coaches);
  }

  Future<void> _loadMyTeams() async {
    if (_uid.isEmpty) return;
    final mine = {_uid};
    try {
      final memberships = await TeamService.streamAthleteTeams(_uid).first;
      for (final d in memberships.docs) {
        final coachId = (d.data() as Map<String, dynamic>)['coachId'];
        if (coachId is String && coachId.isNotEmpty) mine.add(coachId);
      }
    } catch (_) {
      // The highlight is a nicety; the table is still right without it.
    }
    if (mounted) setState(() => _myTeams = mine);
  }

  void _reload() => setState(() => _board = _load());

  Future<void> _refresh() async {
    _reload();
    try {
      await _board;
    } catch (_) {
      // The FutureBuilder shows the error; the spinner just needs to stop.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildSportRow(),
          if (_seasons.length > 1) _buildSeasonRow(),
          _buildBasis(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            child: Icon(LucideIcons.chevronLeft,
                color: AppTheme.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text('Standings',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: selected ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border,
                width: selected ? 2 : 1.5)),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.accentText : AppTheme.muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _buildSportRow() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          for (final s in _kSports)
            _chip(
              label: '${_kSportEmoji[s] ?? ''} $s'.trim(),
              selected: _sport == s,
              onTap: () {
                if (s == _sport) return;
                setState(() {
                  _sport = s;
                  _board = _load();
                });
              },
            ),
        ]),
      );

  /// Only shown once there's more than one season to choose between.
  Widget _buildSeasonRow() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          for (final y in _seasons)
            _chip(
              label: '$y',
              selected: _season == y,
              onTap: () {
                if (y == _season) return;
                setState(() {
                  _season = y;
                  _board = _load();
                });
              },
            ),
        ]),
      );

  /// What the table covers, so a tune-up result missing from it doesn't read
  /// as a bug.
  Widget _buildBasis() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.info, color: AppTheme.muted, size: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                '$_season season · Liga and tournament games count, '
                "tune-ups don't. Ranked by win %.",
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _buildBody() {
    return FutureBuilder<_Board>(
      future: _board,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // A pull-to-refresh keeps the table up under its spinner.
          final previous = snapshot.data;
          if (previous != null &&
              previous.key == _boardKey &&
              previous.table.isNotEmpty) {
            return _buildTable(previous);
          }
          return const _StandingsSkeleton();
        }
        if (snapshot.hasError) {
          return _buildMessage(
            icon: LucideIcons.alertCircle,
            title: 'Something went wrong',
            subtitle: friendlyError(snapshot.error),
            retry: true,
          );
        }
        final board = snapshot.data!;
        if (board.table.isEmpty) {
          return _buildMessage(
            icon: LucideIcons.trophy,
            title: 'No official games yet',
            subtitle: 'The $_season $_sport table starts with the first Liga '
                'or tournament game an organizer records.',
          );
        }
        return _buildTable(board);
      },
    );
  }

  Widget _buildTable(_Board board) {
    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.card,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          StandingsTable(
            table: board.table,
            ranks: board.ranks,
            coaches: board.coaches,
            myTeams: _myTeams,
            onOpen: (coachId, coach, name) => showCoachProfileSheet(context,
                coachId: coachId, coach: coach, fallbackName: name),
          ),
        ],
      ),
    );
  }

  /// Empty and error states, scrollable so pull-to-refresh still works.
  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    bool retry = false,
  }) {
    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.card,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                          color: AppTheme.accentSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accent)),
                      child: Icon(icon, color: AppTheme.accent, size: 32)),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.sub, fontSize: 13, height: 1.5)),
                  if (retry) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Try again',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like the table, so nothing shifts when it loads.
class _StandingsSkeleton extends StatelessWidget {
  const _StandingsSkeleton();

  static const int _rows = 6;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Container(
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(children: [
                SkeletonBox(width: 120, height: 10),
                Spacer(),
                SkeletonBox(width: 110, height: 10),
              ]),
            ),
            for (var i = 0; i < _rows; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.border))),
                child: const Row(children: [
                  SkeletonBox(width: 16, height: 12),
                  SizedBox(width: 12),
                  SkeletonBox(width: 32, height: 32, radius: 9),
                  SizedBox(width: 8),
                  SkeletonBox(width: 96, height: 12),
                  Spacer(),
                  SkeletonBox(width: 110, height: 12),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
