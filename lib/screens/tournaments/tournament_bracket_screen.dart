// lib/screens/tournaments/tournament_bracket_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/bracket_slot.dart';
import '../../models/tournament.dart';
import '../../services/tournament_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/bracket_view.dart';
import '../../utils/error_messages.dart';

const _kRadius = 14.0;

/// The bracket, one round at a time: a stepper across the top shows the whole
/// path (rounds played, the round being played, rounds still to come) and the
/// round picked below it fills the width of the phone. Rounds no team has
/// reached yet appear only as a locked step, not as empty cards.
///
/// The organizer sees actions on it — schedule a matchup, record its
/// result — while everyone else sees the same board read-only. Both read
/// exactly the same documents; the difference is only whether the buttons
/// are drawn, which is what firestore.rules enforces for real.
class TournamentBracketScreen extends StatefulWidget {
  const TournamentBracketScreen({super.key});

  @override
  State<TournamentBracketScreen> createState() =>
      _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  /// Read once, while this route is on top. `Get.arguments` always describes
  /// the top route, so reading it on every build picked up Record Match's
  /// `{'eventId'}` while it was open above this screen: recording a result
  /// updates the tournament, this rebuilt underneath with an empty id, and
  /// `doc('')` threw.
  final String _tournamentId =
      (Get.arguments as Map?)?['tournamentId'] as String? ?? '';

  // Held here rather than created in build, so a rebuild doesn't tear the
  // listeners down and re-subscribe.
  late final _tournamentStream =
      TournamentService.tournamentStream(_tournamentId);
  late final _slotsStream = TournamentService.slotsStream(_tournamentId);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _tournamentStream,
          builder: (context, tSnap) {
            if (tSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2.5));
            }
            final tData = tSnap.data?.data();
            if (tData == null) {
              return _missing('This tournament no longer exists.');
            }
            final tournament = Tournament.fromMap(tSnap.data!.id, tData);
            final isOrganizer = tournament.organizerId == uid;

            return Column(children: [
              _TopBar(tournament: tournament, isOrganizer: isOrganizer),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _slotsStream,
                  builder: (context, sSnap) {
                    if (sSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2.5));
                    }
                    final slots = TournamentService.slotsFrom(sSnap.data!);
                    if (slots.isEmpty) {
                      return _missing('This bracket has no matchups.');
                    }
                    return _BracketBoard(
                      tournament: tournament,
                      slots: slots,
                      isOrganizer: isOrganizer,
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _missing(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 14)),
        ),
      );
}

// ── Header ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Tournament tournament;
  final bool isOrganizer;
  const _TopBar({required this.tournament, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Text(
                    '${tournament.sport} · ${tournament.entrantCount} teams · '
                    '${tournament.venue}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
              ],
            ),
          ),
          if (isOrganizer && !tournament.isCompleted)
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline_rounded,
                  color: AppTheme.muted, size: 20),
            ),
        ]),
        if (tournament.championTeamName != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Get.toNamed('/tournaments/champion',
                arguments: {'tournamentId': tournament.id}),
            child: _championBanner(tournament.championTeamName!),
          ),
        ],
      ]),
    );
  }

  Widget _championBanner(String teamName) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.accent)),
        child: Row(children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppTheme.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHAMPION',
                    style: TextStyle(
                        color: AppTheme.accentText,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(teamName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.accentText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          // Opens the championship page.
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.accentText, size: 22),
        ]),
      );

  void _confirmDelete(BuildContext context) {
    final blocked = tournament.hasMatchData;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(blocked ? "This can't be deleted" : 'Delete this tournament?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            blocked
                ? 'A result has already been recorded, so the bracket has to '
                    'stay. The matches and stats behind it depend on it.'
                : "This can't be undone. No results have been recorded yet, so "
                    'nothing else is affected.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(blocked ? 'OK' : 'Back',
                style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          if (!blocked)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await TournamentService.delete(tournament.id);
                  Get.back();
                } catch (e) {
                  Get.snackbar('Error', friendlyError(e),
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.errorSurface,
                      colorText: AppTheme.errorText,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12);
                }
              },
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── The board ──────────────────────────────────────────

class _BracketBoard extends StatefulWidget {
  final Tournament tournament;
  final List<BracketSlot> slots;
  final bool isOrganizer;

  const _BracketBoard({
    required this.tournament,
    required this.slots,
    required this.isOrganizer,
  });

  @override
  State<_BracketBoard> createState() => _BracketBoardState();
}

class _BracketBoardState extends State<_BracketBoard> {
  /// The round picked on the stepper. Null follows the round being played,
  /// so recording the last quarterfinal moves the view on by itself; a tap
  /// on an earlier round sticks until the organizer taps back.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final summaries = roundSummaries(widget.slots, t.roundCount);
    final current = initialRound(summaries);
    // A picked round that has since become locked can't be shown (it never
    // happens today, but Reset could in principle change it).
    final pickedSummary = summaries
        .where((s) => s.round == _picked && s.stage != RoundStage.locked);
    final summary = pickedSummary.isNotEmpty
        ? pickedSummary.first
        : summaries.firstWhere((s) => s.round == current);

    final inRound = widget.slots
        .where((s) => s.round == summary.round)
        .toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final note = upNextNote(summaries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _StageStepper(
          summaries: summaries,
          selected: summary.round,
          onSelect: (round) =>
              setState(() => _picked = round == current ? null : round),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Text(summary.title.toUpperCase(),
              style: TextStyle(
                  color: AppTheme.sub,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          if (summary.total > 0)
            Text('${summary.played} of ${summary.total} played',
                style: TextStyle(color: AppTheme.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        for (final slot in inRound)
          slot.isBye
              ? _ByeCard(tournament: t, slot: slot)
              : _MatchCard(
                  tournament: t,
                  slot: slot,
                  slots: widget.slots,
                  isOrganizer: widget.isOrganizer,
                ),
        // Brackets made before every bracket had a battle for third can
        // add one from the final round.
        if (widget.isOrganizer &&
            summary.round == t.roundCount &&
            !widget.slots.any((s) => s.isThirdPlace))
          _AddThirdPlaceCard(tournament: t, slots: widget.slots),
        if (note != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.lock_outline_rounded,
                  color: AppTheme.muted, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(note,
                  style: TextStyle(color: AppTheme.sub, fontSize: 12)),
            ),
          ]),
        ],
      ],
    );
  }
}

/// One step per round, joined by lines: gold check for a finished round,
/// solid gold for the round being played, a gold ring for a later round that
/// already has teams, and a muted lock for one no team has reached. Locked
/// steps can't be opened; every other step is a 44dp-plus tap target.
class _StageStepper extends StatelessWidget {
  final List<RoundSummary> summaries;
  final int selected;
  final ValueChanged<int> onSelect;

  const _StageStepper({
    required this.summaries,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < summaries.length; i++)
        Expanded(child: _step(i)),
    ]);
  }

  Widget _step(int i) {
    final s = summaries[i];
    final locked = s.stage == RoundStage.locked;
    final isSelected = s.round == selected;

    // The line into a step is gold once the round before it is finished.
    Color lineInto(int index) => index > 0 &&
            summaries[index - 1].stage == RoundStage.done
        ? AppTheme.accent
        : AppTheme.border;

    Widget line(Color color) =>
        Expanded(child: Container(height: 2, color: color));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: locked ? null : () => onSelect(s.round),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          Row(children: [
            i == 0 ? const Spacer() : line(lineInto(i)),
            _dot(s.stage, isSelected),
            i == summaries.length - 1
                ? const Spacer()
                : line(lineInto(i + 1)),
          ]),
          const SizedBox(height: 6),
          Text(s.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimary
                      : locked
                          ? AppTheme.muted
                          : AppTheme.sub,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _dot(RoundStage stage, bool isSelected) {
    const size = 30.0;
    // The round on screen gets a halo, so a finished round being looked back
    // at is still clearly the one shown.
    final halo = isSelected
        ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.35), blurRadius: 10)]
        : null;
    switch (stage) {
      case RoundStage.done:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppTheme.accent, shape: BoxShape.circle, boxShadow: halo),
          child: const Icon(Icons.check_rounded,
              color: AppTheme.buttonFg, size: 18),
        );
      case RoundStage.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppTheme.accent, shape: BoxShape.circle, boxShadow: halo),
          child: Center(
            child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.buttonFg, shape: BoxShape.circle)),
          ),
        );
      case RoundStage.open:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
              boxShadow: halo),
        );
      case RoundStage.locked:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppTheme.cardNested,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 1.5)),
          child:
              Icon(Icons.lock_outline_rounded, color: AppTheme.muted, size: 14),
        );
    }
  }
}

/// Offers an older bracket the battle for third it was made without. The
/// semifinal losers already known go straight in.
class _AddThirdPlaceCard extends StatelessWidget {
  final Tournament tournament;
  final List<BracketSlot> slots;
  const _AddThirdPlaceCard({required this.tournament, required this.slots});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _confirm(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Icon(Icons.add_circle_outline_rounded,
              color: AppTheme.accentText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add battle for third',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      'The two semifinal losers play for 2nd and 3rd '
                      'runner-up.',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ]),
          ),
        ]),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add a battle for third?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            'The two semifinal losers play one more game. The winner '
            'finishes 2nd runner-up and the loser 3rd runner-up. The '
            'champion is not affected.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await TournamentService.addThirdPlace(tournament, slots);
              } catch (e) {
                Get.snackbar('Error', friendlyError(e),
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.errorSurface,
                    colorText: AppTheme.errorText,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12);
              }
            },
            child: const Text('Add',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// A seed that goes straight through to the next round. Decided when the
/// bracket was made, so it's a line rather than a game card.
class _ByeCard extends StatelessWidget {
  final Tournament tournament;
  final BracketSlot slot;
  const _ByeCard({required this.tournament, required this.slot});

  @override
  Widget build(BuildContext context) {
    final team = slot.entrantA ?? slot.entrantB;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        if (team != null) _seedBadge(team.seed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(team?.teamName ?? '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        Text(
            'Bye to the '
            '${roundTitle(slot.round + 1, tournament.roundCount)}',
            style: TextStyle(color: AppTheme.muted, fontSize: 11)),
      ]),
    );
  }
}

Widget _seedBadge(int seed) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border)),
      child: Center(
          child: Text('$seed',
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800))),
    );

/// One game, full width: its number and status, both teams, and (for the
/// organizer) the one action it needs next. Tapping a card whose game has
/// been set up opens that game.
class _MatchCard extends StatelessWidget {
  final Tournament tournament;
  final BracketSlot slot;
  final List<BracketSlot> slots;
  final bool isOrganizer;

  const _MatchCard({
    required this.tournament,
    required this.slot,
    required this.slots,
    required this.isOrganizer,
  });

  /// Record Match only accepts a game once it has started. A matchup
  /// scheduled before kickoff was stored has no time to check, so it's left
  /// to Record Match to decide.
  bool get _kickedOff =>
      slot.kickoff == null || !slot.kickoff!.isAfter(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final needsOrganizer = isOrganizer &&
        (slot.status == BracketSlot.statusReady ||
            (slot.isScheduled && _kickedOff));
    final eventId = slot.eventId;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: eventId == null
          ? null
          : () => Get.toNamed('/events/detail', arguments: {'eventId': eventId}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(
                color: needsOrganizer ? AppTheme.accent : AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(slot.isThirdPlace ? 'BATTLE FOR THIRD' : 'MATCH ${slot.slot}',
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_statusText(),
                style: TextStyle(
                    color: slot.isScheduled ? AppTheme.sub : AppTheme.muted,
                    fontSize: 11,
                    fontWeight:
                        slot.isScheduled ? FontWeight.w700 : FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          _side(slot.entrantA, slot.scoreA, 'A'),
          const SizedBox(height: 8),
          _side(slot.entrantB, slot.scoreB, 'B'),
          if (isOrganizer) ..._actions(context),
        ]),
      ),
    );
  }

  String _statusText() {
    switch (slot.status) {
      case BracketSlot.statusCompleted:
        return slot.completedAt == null
            ? 'Final score'
            : 'Played ${DateFormat('MMM d').format(slot.completedAt!)}';
      case BracketSlot.statusScheduled:
        return slot.kickoff == null
            ? 'Scheduled'
            : DateFormat('EEE, MMM d · h:mm a').format(slot.kickoff!);
      case BracketSlot.statusReady:
        return 'Not scheduled';
      default:
        return 'Waiting on teams';
    }
  }

  Widget _side(SlotEntrant? entrant, int? score, String side) {
    final won = slot.isDecided && slot.winnerCoachId == entrant?.coachId;
    final lost = slot.isDecided && entrant != null && !won;

    if (entrant == null) {
      return SizedBox(
        height: 22,
        child: Row(children: [
          Text(feederLabel(slot, side, slots) ?? 'Awaiting winner',
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
        ]),
      );
    }

    return Row(children: [
      _seedBadge(entrant.seed),
      const SizedBox(width: 10),
      Expanded(
        child: Text(entrant.teamName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: lost ? AppTheme.sub : AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: won ? FontWeight.w800 : FontWeight.w600)),
      ),
      if (won) ...[
        Icon(Icons.emoji_events_rounded, color: AppTheme.accentText, size: 15),
        const SizedBox(width: 6),
      ],
      if (score != null)
        Text('$score',
            style: TextStyle(
                color: won ? AppTheme.accentText : AppTheme.muted,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
    ]);
  }

  /// The organizer's next step on this game, if it has one.
  List<Widget> _actions(BuildContext context) {
    if (slot.status == BracketSlot.statusReady) {
      return [
        const SizedBox(height: 14),
        _button(
          label: 'Schedule game',
          icon: Icons.event_available_outlined,
          onTap: () => _schedule(context),
        ),
      ];
    }
    if (!slot.isScheduled) return const [];
    return [
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _button(
            label: _kickedOff ? 'Record result' : 'Opens at kickoff',
            icon: _kickedOff ? Icons.scoreboard_outlined : Icons.schedule,
            onTap: _kickedOff
                ? () => Get.toNamed('/matches/record',
                    arguments: {'eventId': slot.eventId})
                : null,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _confirmUnschedule(context),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text('Reset',
                    style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ]),
    ];
  }

  /// A 44dp gold button, greyed when [onTap] is null.
  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: enabled ? AppTheme.accentSurface : AppTheme.cardNested,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: enabled ? AppTheme.accent : AppTheme.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: enabled ? AppTheme.accentText : AppTheme.muted, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: enabled ? AppTheme.accentText : AppTheme.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Organizer actions ────────────────────────────────

  Future<void> _schedule(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final kickoff =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    try {
      await TournamentService.scheduleSlot(
        tournament: tournament,
        slot: slot,
        kickoff: kickoff,
      );
      Get.snackbar(
        'Matchup Scheduled',
        'Both rosters have been notified.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText: AppTheme.accentText,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar('Error', friendlyError(e),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.errorSurface,
          colorText: AppTheme.errorText,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    }
  }

  /// Firestore cannot guarantee the child event still exists — an organizer
  /// may have cancelled it, or it may have been removed outside the app —
  /// so this is the way out of a matchup that can no longer be played.
  void _confirmUnschedule(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset this matchup?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            'The bracket forgets the event that was set up for it, so you can '
            'schedule it again. The event itself is left alone.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await TournamentService.unscheduleSlot(tournament.id, slot.id);
              } catch (e) {
                Get.snackbar('Error', friendlyError(e),
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.errorSurface,
                    colorText: AppTheme.errorText,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12);
              }
            },
            child: const Text('Reset',
                style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
