// lib/screens/events/record_match_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../constants/query_limits.dart';
import '../../models/tournament.dart';
import '../../services/rating_service.dart';
import '../../services/team_service.dart';
import '../../services/tournament_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/event_history.dart';
import '../../utils/event_types.dart';
import '../../utils/firestore_helpers.dart';
import '../../utils/match_lineup.dart';
import '../../widgets/member_profiles.dart';
import '../../widgets/player_avatar.dart';

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
        if (!canRecordResult(data)) {
          Get.back();
          _notice(
              hasResult(data) ? 'Already recorded' : 'Not played yet',
              hasResult(data)
                  ? "This game's result is already recorded."
                  : 'Record this game once its start time has passed.');
          return;
        }
        setState(() => _selectedEvent = data);
        _prefillSides(data);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPreset = false);
    }
  }

  /// uid -> 'A' | 'B' from the coach's roster the player came in with, or
  /// null on an older event that never recorded teams.
  final Map<String, String?> _teamOf = {};
  final Set<String> _satOut = {};
  final Set<String> _collapsed = {};
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _scoreACtrl.dispose();
    _scoreBCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _players =>
      (_selectedEvent?['players'] as List? ?? []).cast<Map<String, dynamic>>();

  /// Starts every player on the team saved at event creation, marked as
  /// played, so the organizer only unchecks no-shows.
  void _prefillSides(Map<String, dynamic> ev) {
    setState(() {
      _teamOf
        ..clear()
        ..addAll(initialTeams(
            (ev['players'] as List? ?? []).cast<Map<String, dynamic>>()));
      _satOut.clear();
      _collapsed.clear();
    });
  }

  void _resetLineup() {
    _teamOf.clear();
    _satOut.clear();
    _collapsed.clear();
  }

  MatchLineup get _lineup => deriveLineup(_players, _teamOf, _satOut);

  String? get _blockReason => recordBlockReason(
      _lineup, _scoreACtrl.text, _scoreBCtrl.text,
      nameA: _sideName(_kSideA), nameB: _sideName(_kSideB));

  void _toggleSatOut(String uid) => setState(() {
        if (!_satOut.remove(uid)) _satOut.add(uid);
      });

  /// Only for a player with no team yet; nobody is ever switched between
  /// teams, since a player belongs to exactly one.
  void _assignTo(String uid, String side) =>
      setState(() => _teamOf[uid] = side);

  /// Every result is confirmed before it is written. A bracket result also
  /// advances a team, which has its own dialog; an ordinary match used to go
  /// straight through, but it is just as permanent — once recorded the event
  /// can no longer be deleted, and the score is what every player's rating is
  /// later updated from — so a mistyped score deserves the same chance to be
  /// caught.
  Future<void> _onSubmitPressed() async {
    if (_isBracketMatch) {
      if (!await _confirmAdvance()) return;
    } else if (!await _confirmRecord()) {
      return;
    }
    await _submit();
  }

  /// The name of one side of the selected event, or "Team A"/"Team B" when the
  /// event has none (older events, or a coach who never named the team).
  String _sideName(String side) {
    final name = (_selectedEvent?[side == _kSideA ? 'teamAName' : 'teamBName']
                as String? ??
            '')
        .trim();
    return name.isNotEmpty ? name : 'Team $side';
  }

  String get _lineupCounts {
    final l = _lineup;
    return '${l.sideA.length} vs ${l.sideB.length} players';
  }

  Future<bool> _confirmRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Record this result?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            '${_sideName(_kSideA)} ${_scoreACtrl.text.trim()} — '
            '${_scoreBCtrl.text.trim()} ${_sideName(_kSideB)}\n'
            '$_lineupCounts\n\n'
            "Check the score: it can't be changed after this"
            '${_ranked ? ", and it decides every player's rating." : '.'}',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Back',
                style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Record',
                style: TextStyle(color: AppTheme.accent, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit() async {
    final lineup = _lineup;
    final sideA = lineup.sideA;
    final sideB = lineup.sideB;
    final scoreA = int.parse(_scoreACtrl.text.trim());
    final scoreB = int.parse(_scoreBCtrl.text.trim());

    final tournamentId = _selectedEvent!['tournamentId'] as String?;
    final slotId = _selectedEvent!['tournamentSlotId'] as String?;

    setState(() => _isSaving = true);
    try {
      if (await RatingService.eventHasResult(
          _selectedEvent!['eventId'] as String)) {
        if (!mounted) return;
        Get.back();
        _notice('Already recorded',
            "This game's result was already recorded, so it wasn't saved again.");
        return;
      }
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
      _afterRecorded(_selectedEvent!['eventId'] as String,
          bracket: tournamentId != null);
    } catch (e) {
      Get.snackbar(
        // The bracket path throws StateErrors whose text is already written
        // for the organizer ("This matchup is no longer in the bracket.").
        'Error', e is StateError ? e.message : friendlyError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorSurface,
        colorText: AppTheme.errorText,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// False for a tune-up, which keeps stats but moves nobody's rating.
  bool get _ranked =>
      countsTowardRankings(_selectedEvent?['eventType'] as String?);

  /// Stats are the second half of every result, so an ordinary game goes
  /// straight on to Add Stats with this game open. A bracket game returns to
  /// the bracket, where the organizer wants to see the winner move on, with
  /// a shortcut instead. Coming from Add Stats, it simply goes back: that
  /// screen reopens the game itself.
  void _afterRecorded(String eventId, {required bool bracket}) {
    final next = _ranked
        ? "Add each player's stats next to update ratings."
        : "Add each player's stats next to close the game.";
    if (Get.previousRoute == '/stats/add') {
      Get.back();
      return;
    }
    if (!bracket) {
      Get.offNamed('/stats/add', arguments: {'eventId': eventId});
      _notice('Match Recorded', next);
      return;
    }
    Get.back();
    Get.snackbar(
      'Match Recorded', next,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.accentSurface,
      colorText: AppTheme.accentText,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () =>
            Get.toNamed('/stats/add', arguments: {'eventId': eventId}),
        child: Text('Add stats',
            style: TextStyle(
                color: AppTheme.accentText, fontWeight: FontWeight.w800)),
      ),
    );
  }

  void _notice(String title, String message) => Get.snackbar(
        title, message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText: AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

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
    // Only the game the slot now points at may settle it. Reset cancels the
    // game it replaces, but ones reset before it did were left live, and a
    // stale result would otherwise advance the bracket.
    if (slot.eventId != _selectedEvent!['eventId']) {
      throw StateError('This game was reset in the bracket, so its result '
          "can't be recorded. Record the matchup's new game instead.");
    }
    final followOn = slots.where((s) => s.id == slot.nextSlotId).toList();
    final nextSlot = followOn.isEmpty ? null : followOn.first;
    // Where a semifinal's loser goes, when the bracket has a battle for third.
    final third = slots.where((s) => s.isThirdPlace).toList();

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
    await TournamentService.stageAdvance(
      batch,
      tournament: tournament,
      slot: slot,
      nextSlot: nextSlot,
      matchId: matchId,
      scoreA: scoreA,
      scoreB: scoreB,
      winnerSide: scoreA > scoreB ? _kSideA : _kSideB,
      thirdPlaceSlot: third.isEmpty ? null : third.first,
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
    final scoreA = int.parse(_scoreACtrl.text.trim());
    final scoreB = int.parse(_scoreBCtrl.text.trim());
    final winnerName = _sideName(scoreA > scoreB ? _kSideA : _kSideB);

    // Worded for the game being settled. Bracket events scheduled before
    // `bracketStage` was stored fall through to the plain advance wording.
    final (title, outcome, action) =
        switch (_selectedEvent?['bracketStage'] as String?) {
      'Final' => (
          'Crown $winnerName champion?',
          '$winnerName wins the tournament.',
          'Crown champion',
        ),
      'Battle for third' => (
          'Confirm third place?',
          '$winnerName finishes 2nd runner-up.',
          'Confirm',
        ),
      _ => (
          'Advance $winnerName?',
          '$winnerName moves on in the bracket.',
          'Advance',
        ),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            '${_sideName(_kSideA)} $scoreA — $scoreB ${_sideName(_kSideB)}\n'
            '$_lineupCounts\n\n'
            '$outcome This cannot be undone.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:
                Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action,
                style: const TextStyle(
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
                _resetLineup();
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
          Text(_selectedEvent == null ? 'Select an event' : 'Confirm who played & enter the score',
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
        // The game that just ended first — it is the one being recorded. The
        // query's 'upcoming' status is only ever the creation-time value, so
        // this list has always held finished games too.
        // Only played games with no result: a result is recorded once, and
        // never for a game that hasn't started.
        final docs = eventsForResults(snapshot.data?.docs ?? [],
                data: (d) => d.data() as Map<String, dynamic>)
            .where((d) => canRecordResult(d.data() as Map<String, dynamic>))
            .toList();
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No games waiting for a result.\nA game appears here once '
                'its start time has passed.',
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
                      // The date, so two events with similar names can be
                      // told apart.
                      Text(
                        [
                          ev['sport'] as String? ?? '',
                          if (asTimestamp(ev['eventDate']) != null)
                            DateFormat('MMM d')
                                .format(asTimestamp(ev['eventDate'])!.toDate()),
                          '${ev['playerCount'] ?? 0} players',
                        ].where((s) => s.isNotEmpty).join(' · '),
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
    final byUid = {
      for (final p in _players)
        if (p['uid'] is String) p['uid'] as String: p,
    };
    final lineup = _lineup;
    final reason = _blockReason;

    // One builder over every uid in the event: it refetches only when that
    // set changes, so checking or moving a player never reloads the avatars.
    return MemberProfilesBuilder(
      uids: byUid.keys.toList(),
      builder: (context, profiles) =>
          _buildFormBody(byUid, lineup, reason, profiles),
    );
  }

  Widget _buildFormBody(
    Map<String, Map<String, dynamic>> byUid,
    MatchLineup lineup,
    String? reason,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Uncheck anyone who sat out.',
          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        const SizedBox(height: 12),
        if (lineup.unassigned.isNotEmpty) ...[
          _buildUnassignedCard(lineup.unassigned, byUid, profiles),
          const SizedBox(height: 12),
        ],
        _buildTeamCard(_kSideA, lineup.rosterA, lineup.sideA.length, byUid,
            profiles),
        const SizedBox(height: 12),
        _buildTeamCard(_kSideB, lineup.rosterB, lineup.sideB.length, byUid,
            profiles),
        const SizedBox(height: 20),
        // A badminton result is the sets each side won (2–1), which is what
        // Add Stats checks each player's Sets Won against.
        Text(
            _selectedEvent?['sport'] == 'Badminton'
                ? 'Final Score (sets won)'
                : 'Final Score',
            style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          // The real team names, not "Side A"/"Side B" — the easiest way to
          // enter a score the wrong way round was not knowing which box was
          // which team.
          Expanded(child: _scoreField(_sideName(_kSideA), _scoreACtrl)),
          const SizedBox(width: 12),
          Expanded(child: _scoreField(_sideName(_kSideB), _scoreBCtrl)),
        ]),
        const SizedBox(height: 28),
        _isSaving
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: reason == null ? _onSubmitPressed : null,
                  child: Text(
                      _isBracketMatch ? 'Record & Advance' : 'Record Match'),
                ),
              ),
        // Neutral, not red: "Enter both scores" is where everyone starts.
        if (!_isSaving && reason != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(reason,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  Widget _buildTeamCard(
    String side,
    List<String> roster,
    int playedCount,
    Map<String, Map<String, dynamic>> byUid,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    final name = _sideName(side);
    final collapsed = _collapsed.contains(side);
    final nobodyPlayed = playedCount == 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border)),
      child: Material(
        color: Colors.transparent,
        child: Column(children: [
          InkWell(
            onTap: () => setState(() =>
                collapsed ? _collapsed.remove(side) : _collapsed.add(side)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(children: [
                Expanded(child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w800))),
                const SizedBox(width: 8),
                // Stays visible when folded, so a team can't be hidden empty.
                if (nobodyPlayed) ...[
                  Icon(Icons.error_outline_rounded,
                      color: AppTheme.errorText, size: 15),
                  const SizedBox(width: 4),
                ],
                Text('$playedCount of ${roster.length} played',
                  style: TextStyle(
                    color: nobodyPlayed ? AppTheme.errorText : AppTheme.sub,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: AppTheme.muted, size: 22),
              ]),
            ),
          ),
          if (!collapsed) ...[
            Container(height: 1, color: AppTheme.border),
            if (nobodyPlayed) _buildEmptyTeamNote(name, roster.isEmpty),
            for (final uid in roster)
              _buildPlayerRow(byUid[uid]!, profiles),
          ],
        ]),
      ),
    );
  }

  Widget _buildEmptyTeamNote(String name, bool nobodyOnTeam) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.errorText, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nobodyOnTeam
                  ? 'No players on $name. This event was created with only '
                      "one team's roster, so its result can't be recorded."
                  : 'Everyone on $name is marked sat out. Check each player '
                      'who played.',
              style: TextStyle(
                  color: AppTheme.errorText, fontSize: 12, height: 1.4)),
          ),
        ]),
      );

  Widget _buildPlayerRow(Map<String, dynamic> p,
      Map<String, Map<String, dynamic>> profiles) {
    final uid = p['uid'] as String;
    final played = !_satOut.contains(uid);
    final identity = resolveMemberIdentity(profiles[uid],
        fallbackName: p['fullName'] as String? ?? '');
    final position = p['position'] as String? ?? '';

    return InkWell(
      onTap: () => _toggleSatOut(uid),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        child: Row(children: [
          Checkbox(
            value: played,
            onChanged: (_) => _toggleSatOut(uid),
            activeColor: AppTheme.accent,
            checkColor: AppTheme.buttonFg,
            side: BorderSide(color: AppTheme.muted, width: 1.5),
          ),
          Expanded(
            child: Opacity(
              opacity: played ? 1 : 0.45,
              child: Row(children: [
                PlayerAvatar(
                    name: identity.name,
                    photoUrl: identity.photoUrl,
                    size: 36, radius: 10, fontSize: 12),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(identity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                      if (position.isNotEmpty)
                        Text(position,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          // Outside the Opacity, so the label stays readable on a dimmed row.
          if (!played)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('Sat out', style: TextStyle(color: AppTheme.sub,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  /// Only shown for older events whose players were never split into teams.
  Widget _buildUnassignedCard(
    List<String> uids,
    Map<String, Map<String, dynamic>> byUid,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Not on a team', style: TextStyle(color: AppTheme.textPrimary,
            fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text("Won't be recorded unless added. Tap a team to add them.",
          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        const SizedBox(height: 10),
        for (final uid in uids) _buildUnassignedRow(byUid[uid]!, profiles),
      ]),
    );
  }

  Widget _buildUnassignedRow(Map<String, dynamic> p,
      Map<String, Map<String, dynamic>> profiles) {
    final uid = p['uid'] as String;
    final identity = resolveMemberIdentity(profiles[uid],
        fallbackName: p['fullName'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        PlayerAvatar(
            name: identity.name,
            photoUrl: identity.photoUrl,
            size: 32, radius: 9, fontSize: 11),
        const SizedBox(width: 10),
        Expanded(child: Text(identity.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        _sideChip(_sideName(_kSideA), () => _assignTo(uid, _kSideA)),
        const SizedBox(width: 8),
        _sideChip(_sideName(_kSideB), () => _assignTo(uid, _kSideB)),
      ]),
    );
  }

  Widget _sideChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        // Capped so a long team name can't crowd out the player's name.
        constraints: const BoxConstraints(minWidth: 44, maxWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
        child: Center(widthFactor: 1, child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12, fontWeight: FontWeight.w700))),
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
