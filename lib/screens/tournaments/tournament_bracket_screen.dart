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
import '../../utils/bracket.dart';
import '../../utils/error_messages.dart';

const _kRadius = 14.0;
const _kColumnWidth = 210.0;

/// The bracket itself: every round side by side, scrolling horizontally,
/// from the opening round through to the champion.
///
/// The organizer sees actions on it — schedule a matchup, record its
/// result — while everyone else sees the same board read-only. Both read
/// exactly the same documents; the difference is only whether the buttons
/// are drawn, which is what firestore.rules enforces for real.
class TournamentBracketScreen extends StatelessWidget {
  const TournamentBracketScreen({super.key});

  String get _tournamentId =>
      (Get.arguments as Map?)?['tournamentId'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: TournamentService.tournamentStream(_tournamentId),
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
                  stream: TournamentService.slotsStream(_tournamentId),
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
          _championBanner(tournament.championTeamName!),
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
                      backgroundColor: const Color(0xFF2A1A1A),
                      colorText: AppTheme.error,
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

class _BracketBoard extends StatelessWidget {
  final Tournament tournament;
  final List<BracketSlot> slots;
  final bool isOrganizer;

  const _BracketBoard({
    required this.tournament,
    required this.slots,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<BracketSlot>>{};
    for (final s in slots) {
      rounds.putIfAbsent(s.round, () => []).add(s);
    }
    final roundNumbers = rounds.keys.toList()..sort();

    // Rounds sit side by side and the whole board scrolls sideways, which
    // is the only layout that stays readable on a phone once a bracket is
    // more than four teams wide.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: roundNumbers.map((round) {
          return Container(
            width: _kColumnWidth,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      roundLabel(round, tournament.roundCount).toUpperCase(),
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800)),
                ),
                ...rounds[round]!.map((slot) => _SlotCard(
                      tournament: tournament,
                      slot: slot,
                      slots: slots,
                      isOrganizer: isOrganizer,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Tournament tournament;
  final BracketSlot slot;
  final List<BracketSlot> slots;
  final bool isOrganizer;

  const _SlotCard({
    required this.tournament,
    required this.slot,
    required this.slots,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
              color: slot.status == BracketSlot.statusReady
                  ? AppTheme.accent
                  : AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _side(slot.entrantA, slot.scoreA, 'A'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: AppTheme.border),
        ),
        _side(slot.entrantB, slot.scoreB, 'B'),
        const SizedBox(height: 10),
        _statusRow(context),
      ]),
    );
  }

  Widget _side(SlotEntrant? entrant, int? score, String side) {
    final won = slot.isDecided && slot.winnerCoachId == entrant?.coachId;
    final lost = slot.isDecided && entrant != null && !won;

    if (entrant == null) {
      return Row(children: [
        Expanded(
          child: Text(slot.isBye ? '—' : 'Awaiting winner',
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ),
      ]);
    }

    return Row(children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border)),
        child: Center(
            child: Text('${entrant.seed}',
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(entrant.teamName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: lost ? AppTheme.sub : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: won ? FontWeight.w800 : FontWeight.w600)),
      ),
      if (won) ...[
        const Icon(Icons.emoji_events_rounded, color: AppTheme.accent, size: 13),
        const SizedBox(width: 6),
      ],
      if (score != null)
        Text('$score',
            style: TextStyle(
                color: won ? AppTheme.accent : AppTheme.muted,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _statusRow(BuildContext context) {
    switch (slot.status) {
      case BracketSlot.statusBye:
        return _note('Bye — advances automatically');

      case BracketSlot.statusAwaiting:
        return _note('Waiting on an earlier round');

      case BracketSlot.statusCompleted:
        return _note(slot.completedAt == null
            ? 'Final score'
            : 'Played ${DateFormat('MMM d').format(slot.completedAt!)}');

      case BracketSlot.statusReady:
        if (!isOrganizer) return _note('Not scheduled yet');
        return _action(
          label: 'Schedule',
          icon: Icons.event_available_outlined,
          onTap: () => _schedule(context),
        );

      case BracketSlot.statusScheduled:
        if (!isOrganizer) return _note('Scheduled');
        return Column(children: [
          _action(
            label: 'Record result',
            icon: Icons.scoreboard_outlined,
            onTap: () => Get.toNamed('/matches/record',
                arguments: {'eventId': slot.eventId}),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _confirmUnschedule(context),
            child: Text('Reset',
                style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ),
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _note(String text) => Text(text,
      style: TextStyle(color: AppTheme.muted, fontSize: 11));

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.accentText, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: AppTheme.accentText,
                  fontSize: 12,
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
          backgroundColor: const Color(0xFF2A1A1A),
          colorText: AppTheme.error,
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
                    backgroundColor: const Color(0xFF2A1A1A),
                    colorText: AppTheme.error,
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
