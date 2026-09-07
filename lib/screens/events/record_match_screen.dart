// lib/screens/events/record_match_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../constants/query_limits.dart';
import '../../models/tournament.dart';
import '../../services/rating_service.dart';
import '../../services/tournament_service.dart';
import '../../utils/error_messages.dart';

const _kSideA = 'A';
const _kSideB = 'B';

/// Lets a coach/organizer record who played whom at an event: splits the
/// roster into two sides and enters the final score. This becomes the
/// match record that RatingService.finalizeMatch later applies Elo
/// updates against, once every participant's stats are in.
///
/// If the event belongs to a tournament bracket, the same submit also
/// advances the winner — see [_recordBracketMatch]. Optionally takes
/// `Get.arguments` `{'eventId': ...}` to open straight onto one event,
/// which is how the bracket screen sends the organizer here.
class RecordMatchScreen extends StatefulWidget {
  const RecordMatchScreen({super.key});
  @override
  State<RecordMatchScreen> createState() => _RecordMatchScreenState();
}

class _RecordMatchScreenState extends State<RecordMatchScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  Map<String, dynamic>? _selectedEvent;

  String get _presetEventId =>
      (Get.arguments as Map?)?['eventId'] as String? ?? '';

  /// True once an event is chosen and it turns out to be a bracket matchup.
  bool get _isBracketMatch => _selectedEvent?['tournamentId'] != null;

  bool _isLoadingPreset = false;

  @override
  void initState() {
    super.initState();
    if (_presetEventId.isNotEmpty) _loadPresetEvent();
  }

  /// Opens straight onto the event the caller named, so an organizer coming
  /// from a bracket doesn't have to find that matchup again in a list that
  /// a tournament has just filled with fifteen near-identical entries.
  Future<void> _loadPresetEvent() async {
    setState(() => _isLoadingPreset = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(_presetEventId)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() => _selectedEvent = data);
        _prefillSides(data);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreset = false);
    }
  }

  /// uid -> 'A' | 'B'. A player absent from this map is unassigned.
  final Map<String, String> _sides = {};
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _scoreACtrl.dispose();
    _scoreBCtrl.dispose();
    super.dispose();
  }

  /// Prefills the split from each player's team, assigned at event
  /// creation, so the organizer isn't re-splitting the same roster from
  /// scratch every time a match is recorded. Any individual player can
  /// still be flipped afterwards — which is how a no-show is dropped.
  void _prefillSides(Map<String, dynamic> ev) {
    setState(() {
      _sides.clear();
      for (final p
          in (ev['players'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final team = p['team'] as String?;
        if (team == _kSideA || team == _kSideB) {
          _sides[p['uid'] as String] = team!;
        }
      }
    });
  }

  bool get _canSubmit {
    final sideA = _sides.entries.where((e) => e.value == _kSideA);
    final sideB = _sides.entries.where((e) => e.value == _kSideB);
    if (sideA.isEmpty || sideB.isEmpty) return false;
    final scoreA = int.tryParse(_scoreACtrl.text.trim());
    final scoreB = int.tryParse(_scoreBCtrl.text.trim());
    if (scoreA == null || scoreB == null) return false;
    return scoreA != scoreB;
  }

  /// A bracket result is confirmed before it is written, because advancing
  /// a team is not reversible; an ordinary match goes straight through, as
  /// it always has.
  Future<void> _onSubmitPressed() async {
    if (_isBracketMatch && !await _confirmAdvance()) return;
    await _submit();
  }

  Future<void> _submit() async {
    final sideA = _sides.entries
        .where((e) => e.value == _kSideA)
        .map((e) => e.key)
        .toList();
    final sideB = _sides.entries
        .where((e) => e.value == _kSideB)
        .map((e) => e.key)
        .toList();
    final scoreA = int.parse(_scoreACtrl.text.trim());
    final scoreB = int.parse(_scoreBCtrl.text.trim());

    final tournamentId = _selectedEvent!['tournamentId'] as String?;
    final slotId = _selectedEvent!['tournamentSlotId'] as String?;

    setState(() => _isSaving = true);
    try {
      if (tournamentId != null && slotId != null) {
        await _recordBracketMatch(
          tournamentId: tournamentId,
          slotId: slotId,
          sideA: sideA,
          sideB: sideB,
          scoreA: scoreA,
          scoreB: scoreB,
        );
      } else {
        await RatingService.recordMatch(
          eventId: _selectedEvent!['eventId'] as String,
          sport: _selectedEvent!['sport'] as String,
          sideA: sideA,
          sideB: sideB,
          scoreA: scoreA,
          scoreB: scoreB,
          recordedBy: _uid,
        );
      }
      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'Match Recorded',
        'Add each player\'s stats next to finalize ratings',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText: AppTheme.accentText,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error', friendlyError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2A1A1A),
        colorText: AppTheme.error,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Records a bracket matchup and advances its winner in one commit.
  ///
  /// The match write and the bracket write are staged onto the same batch
  /// deliberately: if they were two commits, a failure between them would
  /// leave a recorded result the bracket never acted on, and no screen
  /// would be able to tell that from a match still waiting to be played.
  Future<void> _recordBracketMatch({
    required String tournamentId,
    required String slotId,
    required List<String> sideA,
    required List<String> sideB,
    required int scoreA,
    required int scoreB,
  }) async {
    final db = FirebaseFirestore.instance;

    final tSnap = await db.collection('tournaments').doc(tournamentId).get();
    final tData = tSnap.data();
    if (tData == null) {
      throw StateError('This match belongs to a tournament that no longer exists.');
    }
    final tournament = Tournament.fromMap(tSnap.id, tData);

    final slots = TournamentService.slotsFrom(
        await TournamentService.slotsOf(tournamentId).get());
    final slot = slots.firstWhere(
      (s) => s.id == slotId,
      orElse: () => throw StateError('This matchup is no longer in the bracket.'),
    );
    final followOn = slots.where((s) => s.id == slot.nextSlotId).toList();
    final nextSlot = followOn.isEmpty ? null : followOn.first;

    final batch = db.batch();
    final matchId = await RatingService.recordMatch(
      eventId: _selectedEvent!['eventId'] as String,
      sport: _selectedEvent!['sport'] as String,
      sideA: sideA,
      sideB: sideB,
      scoreA: scoreA,
      scoreB: scoreB,
      recordedBy: _uid,
      writeBatch: batch,
    );
    TournamentService.stageAdvance(
      batch,
      tournament: tournament,
      slot: slot,
      nextSlot: nextSlot,
      matchId: matchId,
      scoreA: scoreA,
      scoreB: scoreB,
      winnerSide: scoreA > scoreB ? _kSideA : _kSideB,
    );
    await batch.commit();
  }

  /// Names the team that will advance before anything is written.
  ///
  /// Sides are still editable on a bracket matchup — an organizer has to be
  /// able to drop a no-show — so this is the point at which a roster that
  /// has been shuffled onto the wrong side becomes visible, while it can
  /// still be corrected. Advancing is not undoable.
  Future<bool> _confirmAdvance() async {
    final ev = _selectedEvent!;
    final scoreA = int.parse(_scoreACtrl.text.trim());
    final scoreB = int.parse(_scoreBCtrl.text.trim());
    final aWins = scoreA > scoreB;
    final winnerName =
        (aWins ? ev['teamAName'] : ev['teamBName']) as String? ?? 'The winner';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Advance $winnerName?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            '${ev['teamAName']} $scoreA — $scoreB ${ev['teamBName']}\n\n'
            '$winnerName moves on in the bracket. This cannot be undone.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:
                Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Advance',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: _isLoadingPreset
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2.5))
                : _selectedEvent == null
                    ? _buildEventPicker()
                    : _buildSidesForm(),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            // Arriving with an event already chosen means there is no
            // picker behind this screen to step back to.
            if (_selectedEvent == null || _presetEventId.isNotEmpty) {
              Get.back();
            } else {
              setState(() {
                _selectedEvent = null;
                _sides.clear();
                _scoreACtrl.clear();
                _scoreBCtrl.clear();
              });
            }
          },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
            child: Icon(
              _selectedEvent == null || _presetEventId.isNotEmpty
                  ? Icons.close_rounded
                  : Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary,
              size: _selectedEvent == null || _presetEventId.isNotEmpty ? 18 : 16),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Record Match', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          Text(_selectedEvent == null ? 'Select an event' : 'Split the roster & enter the score',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildEventPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: _uid)
          .where('status', isEqualTo: 'upcoming')
          // A single tournament can add a dozen or more events to this
          // list, which is exactly the unbounded growth kMaxListQuery
          // exists to cap.
          .limit(kMaxListQuery)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No upcoming events to record a match for',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.sub, fontSize: 14)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final ev = docs[i].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEvent = ev);
                _prefillSides(ev);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev['name'] as String? ?? '',
                        style: TextStyle(color: AppTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('${ev['sport']} · ${ev['playerCount']} players',
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                    ],
                  )),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidesForm() {
    final players = (_selectedEvent?['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tap each player to assign them to a side',
          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        const SizedBox(height: 12),
        ...players.map((p) => _buildPlayerRow(p)),
        const SizedBox(height: 20),
        Text('Final Score', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _scoreField('Side A', _scoreACtrl)),
          const SizedBox(width: 12),
          Expanded(child: _scoreField('Side B', _scoreBCtrl)),
        ]),
        const SizedBox(height: 28),
        _isSaving
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _onSubmitPressed : null,
                  child: Text(
                      _isBracketMatch ? 'Record & Advance' : 'Record Match'),
                ),
              ),
      ]),
    );
  }

  void _toggleSide(String uid, String side) {
    setState(() {
      if (_sides[uid] == side) {
        _sides.remove(uid);
      } else {
        _sides[uid] = side;
      }
    });
  }

  Widget _buildPlayerRow(Map<String, dynamic> p) {
    final uid = p['uid'] as String;
    final side = _sides[uid];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Expanded(child: Text(p['fullName'] as String? ?? '',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600))),
          _sideChip('A', side == _kSideA, () => _toggleSide(uid, _kSideA)),
          const SizedBox(width: 8),
          _sideChip('B', side == _kSideB, () => _toggleSide(uid, _kSideB)),
        ]),
      ),
    );
  }

  Widget _sideChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 32,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSurface : AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border)),
        child: Center(child: Text(label, style: TextStyle(
          color: selected ? AppTheme.accentText : AppTheme.muted,
          fontSize: 13, fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _scoreField(String label, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: AppTheme.sub,
            fontSize: 10, fontWeight: FontWeight.w600)),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: AppTheme.muted, fontSize: 18),
            border: InputBorder.none, isDense: true,
            contentPadding: const EdgeInsets.only(top: 4)),
        ),
      ]),
    );
  }
}
