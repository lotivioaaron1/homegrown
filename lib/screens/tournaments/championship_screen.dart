// lib/screens/tournaments/championship_screen.dart
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/bracket_slot.dart';
import '../../models/tournament.dart';
import '../../services/team_service.dart';
import '../../services/tournament_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/championships.dart';
import '../../utils/stat_scoring.dart';
import '../../widgets/member_profiles.dart';
import '../../widgets/player_avatar.dart';

const _kRadius = 16.0;

/// A tournament's champion, celebrated: the trophy, the team, the final score,
/// its averages across the tournament, the final standings and the roster
/// that won it.
///
/// Opened from the champion notification, the bracket's champion banner, and
/// every showcase (profile shelf, team titles, Home spotlight). Winning a
/// tournament happens rarely, so this is the one screen in the app that
/// greets you with motion: the trophy settles in and one burst of confetti
/// falls. Both are skipped when the device asks for reduced motion.
class ChampionshipScreen extends StatefulWidget {
  const ChampionshipScreen({super.key});

  @override
  State<ChampionshipScreen> createState() => _ChampionshipScreenState();
}

class _ChampionshipScreenState extends State<ChampionshipScreen>
    with SingleTickerProviderStateMixin {
  /// Read once, while this route is on top (see TournamentBracketScreen).
  final String _tournamentId =
      (Get.arguments as Map?)?['tournamentId'] as String? ?? '';

  late final _tournamentStream =
      TournamentService.tournamentStream(_tournamentId);

  /// Every slot of the bracket, for the final's score and the standings.
  /// Read once, as soon as the tournament has loaded.
  Future<List<BracketSlot>>? _slots;

  /// The champion's per-game averages, read once the slots are in. Null
  /// when no stats were recorded for its games.
  Future<TeamAverages?>? _averages;

  late final AnimationController _celebration = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _celebration.value = 1;
    } else {
      _celebration.forward();
    }
  }

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  Future<List<BracketSlot>> _loadSlots(Tournament t) async =>
      TournamentService.slotsFrom(await TournamentService.slotsOf(t.id).get());

  /// Offline or refused, the averages card just doesn't appear.
  Future<TeamAverages?> _loadAverages(
      Tournament t, List<BracketSlot> slots) async {
    try {
      final lines = await TournamentService.statLinesFor(
          matchIdsFor(t.championCoachId!, slots));
      return championAverages(t, slots, lines);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _tournamentStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2.5));
            }
            final data = snap.data?.data();
            if (data == null) {
              return _message('This tournament no longer exists.');
            }
            final t = Tournament.fromMap(snap.data!.id, data);
            if (!t.isCompleted || t.championCoachId == null) {
              return _message("This tournament hasn't crowned a champion yet.");
            }
            _slots ??= _loadSlots(t);
            _averages ??= _slots!.then((slots) => _loadAverages(t, slots));

            return Stack(children: [
              _content(t),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _celebration,
                    builder: (context, _) => CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _celebration.value,
                        colors: [
                          AppTheme.accent,
                          AppTheme.accentText,
                          AppTheme.textPrimary,
                          AppTheme.sub,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _content(Tournament t) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final champion = t.entrantFor(t.championCoachId!);
    final teamName = t.championTeamName ?? champion?.teamName ?? 'Champion';
    final when = t.completedAt == null
        ? ''
        : ' · ${DateFormat('MMM d, y').format(t.completedAt!)}';

    // The trophy settles in over the first quarter of the celebration.
    final entrance = CurvedAnimation(
        parent: _celebration,
        curve: const Interval(0, 0.25, curve: Curves.easeOutCubic));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Align(alignment: Alignment.centerLeft, child: _backButton()),
        const SizedBox(height: 12),
        Center(
          child: FadeTransition(
            opacity: entrance,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(entrance),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                        blurRadius: 28),
                  ],
                ),
                child: Icon(Icons.emoji_events_rounded,
                    color: AppTheme.accentText, size: 60),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('CHAMPIONS',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.accentText,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(teamName,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 28,
                height: 1.15,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${t.name} · ${t.sport}$when',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        if (isChampion(t, uid)) ...[
          const SizedBox(height: 14),
          Center(child: _youWonPill()),
        ],
        const SizedBox(height: 24),
        FutureBuilder<List<BracketSlot>>(
          future: _slots,
          builder: (context, snap) {
            final slots = snap.data ?? const <BracketSlot>[];
            final finals = slots.where((s) => s.isFinal && s.isDecided);
            final standings = finalStandings(t, slots);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (finals.isNotEmpty) ...[
                    _finalScore(finals.first),
                    const SizedBox(height: 20),
                  ],
                  FutureBuilder<TeamAverages?>(
                    future: _averages,
                    builder: (context, snap) {
                      final averages = snap.data;
                      if (averages == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _averagesCard(averages),
                      );
                    },
                  ),
                  if (standings.isNotEmpty) ...[
                    _standings(standings),
                    const SizedBox(height: 20),
                  ],
                ]);
          },
        ),
        if (champion != null) _roster(champion),
        const SizedBox(height: 24),
        _viewBracketButton(t.id),
      ],
    );
  }

  Widget _youWonPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.celebration_rounded, color: AppTheme.accentText, size: 16),
          const SizedBox(width: 6),
          Text('You won this one!',
              style: TextStyle(
                  color: AppTheme.accentText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  /// The final's scoreline, the champion first.
  Widget _finalScore(BracketSlot slot) {
    final winnerIsA = slot.winnerCoachId == slot.entrantA?.coachId;
    final winner = winnerIsA ? slot.entrantA : slot.entrantB;
    final loser = winnerIsA ? slot.entrantB : slot.entrantA;
    final winnerScore = winnerIsA ? slot.scoreA : slot.scoreB;
    final loserScore = winnerIsA ? slot.scoreB : slot.scoreA;

    Widget row(String name, int? score, {required bool won}) => Row(children: [
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: won ? AppTheme.textPrimary : AppTheme.sub,
                    fontSize: 15,
                    fontWeight: won ? FontWeight.w800 : FontWeight.w600)),
          ),
          if (won) ...[
            Icon(Icons.emoji_events_rounded,
                color: AppTheme.accentText, size: 15),
            const SizedBox(width: 6),
          ],
          Text(score == null ? '—' : '$score',
              style: TextStyle(
                  color: won ? AppTheme.accentText : AppTheme.muted,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ]);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('FINAL'),
        const SizedBox(height: 10),
        row(winner?.teamName ?? '—', winnerScore, won: true),
        const SizedBox(height: 8),
        row(loser?.teamName ?? '—', loserScore, won: false),
      ]),
    );
  }

  /// The champion's box score per game across the tournament, three to a
  /// row, in the same categories and number format as a player's profile.
  Widget _averagesCard(TeamAverages a) {
    final note = a.games == a.gamesPlayed
        ? 'Across ${a.games} game${a.games == 1 ? '' : 's'}'
        : 'From the ${a.games} of ${a.gamesPlayed} games with stats recorded';

    Widget tile(String label, double value, double width) => Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppTheme.cardNested,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                label == 'Win Rate %'
                    ? '${formatStatAverage(value)}%'
                    : formatStatAverage(value),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('TEAM AVERAGES · PER GAME'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: LayoutBuilder(builder: (context, constraints) {
          const gap = 8.0;
          final width = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final e in a.averages.entries) tile(e.key, e.value, width),
          ]);
        }),
      ),
      const SizedBox(height: 8),
      Text(note, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
    ]);
  }

  /// Champion down to 3rd runner-up, each with its medal. Semifinal losers
  /// share 2nd runner-up until a battle for third separates them.
  Widget _standings(List<Standing> standings) {
    final anyJoint = standings.any((s) => s.joint);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('FINAL STANDINGS'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          for (final s in standings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                _medal(s.place),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label.toUpperCase(),
                            style: TextStyle(
                                color: s.place == 1
                                    ? AppTheme.accentText
                                    : AppTheme.muted,
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(s.teamName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: s.place == 1
                                    ? FontWeight.w900
                                    : FontWeight.w700)),
                      ]),
                ),
              ]),
            ),
        ]),
      ),
      if (anyJoint) ...[
        const SizedBox(height: 8),
        Text('The battle for third hasn’t been played yet.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      ],
    ]);
  }

  /// Gold for the champion, silver and bronze for the runners-up after, and
  /// a plain numbered disc for 4th. The metal colours are the same in both
  /// themes, like real medals, and always carry dark text.
  Widget _medal(int place) {
    const silver = Color(0xFFC3C8D1);
    const bronze = Color(0xFFCD8B4C);
    final fill = switch (place) {
      1 => AppTheme.accent,
      2 => silver,
      3 => bronze,
      _ => AppTheme.cardNested,
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: place > 3 ? Border.all(color: AppTheme.border) : null),
      child: Center(
        child: place == 1
            ? const Icon(Icons.emoji_events_rounded,
                color: AppTheme.buttonFg, size: 18)
            : Text('$place',
                style: TextStyle(
                    color: place > 3 ? AppTheme.muted : AppTheme.buttonFg,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
      ),
    );
  }

  /// The coach and every player the champion entered with.
  Widget _roster(TournamentEntrant champion) {
    final uids = [champion.coachId, ...champion.players.map((p) => p.uid)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('WINNING ROSTER · ${champion.players.length}'),
      const SizedBox(height: 10),
      MemberProfilesBuilder(
        uids: uids,
        builder: (context, profiles) {
          Widget person(String uid, String fallback, String role) {
            final who = resolveMemberIdentity(profiles[uid],
                fallbackName: fallback.isEmpty ? 'Player' : fallback);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                PlayerAvatar(name: who.name, photoUrl: who.photoUrl, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(who.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                if (role.isNotEmpty)
                  Text(role,
                      style: TextStyle(color: AppTheme.muted, fontSize: 12)),
              ]),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              person(champion.coachId, champion.coachName, 'Coach'),
              for (final p in champion.players)
                person(p.uid, p.fullName, p.position),
            ]),
          );
        },
      ),
    ]);
  }

  /// Back to the bracket when that's where this was opened from, otherwise
  /// onto it, so the bracket never stacks on itself.
  Widget _viewBracketButton(String tournamentId) => SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => Get.previousRoute == '/tournaments/detail'
              ? Get.back()
              : Get.toNamed('/tournaments/detail',
                  arguments: {'tournamentId': tournamentId}),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.accentText,
            side: const BorderSide(color: AppTheme.accent),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: const Text('View bracket',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w800));

  Widget _backButton() => GestureDetector(
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
      );

  Widget _message(String text) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(alignment: Alignment.centerLeft, child: _backButton()),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.sub, fontSize: 14)),
            ),
          ),
        ),
      ]);
}

/// One burst of confetti thrown up from the trophy, falling under gravity
/// and fading out over the last third. [progress] runs 0 to 1 across the
/// burst; the pieces are fixed by a seeded random so a rebuild mid-flight
/// doesn't reshuffle them.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _ConfettiPainter({required this.progress, required this.colors});

  static final List<_Piece> _pieces = _makePieces();

  static List<_Piece> _makePieces() {
    final rnd = math.Random(7);
    return List.generate(70, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.55 + rnd.nextDouble() * 0.6;
      return _Piece(
        vx: math.cos(angle) * speed * 0.8,
        vy: math.sin(angle) * speed,
        spin: (rnd.nextDouble() - 0.5) * 14,
        width: 5 + rnd.nextDouble() * 5,
        height: 3 + rnd.nextDouble() * 3,
        colorIndex: i,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    const seconds = 1.8;
    const gravity = 1.1; // in screen heights per second squared
    final t = progress * seconds;
    final fade = progress < 0.66 ? 1.0 : (1 - progress) / 0.34;
    // The burst starts at the trophy, near the top of the page.
    final origin = Offset(size.width / 2, size.height * 0.2);
    final paint = Paint();

    for (final p in _pieces) {
      final dx = p.vx * t * size.height;
      final dy = (p.vy * t + 0.5 * gravity * t * t) * size.height;
      paint.color =
          colors[p.colorIndex % colors.length].withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * t);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Piece {
  final double vx;
  final double vy;
  final double spin;
  final double width;
  final double height;
  final int colorIndex;

  const _Piece({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.width,
    required this.height,
    required this.colorIndex,
  });
}
