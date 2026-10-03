import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../services/rating_service.dart';
import '../../services/team_service.dart';
import '../../utils/event_history.dart';
import '../../utils/event_types.dart';
import '../../utils/firestore_helpers.dart';
import '../../utils/match_players.dart';
import '../../utils/stat_limits.dart';
import '../../utils/stat_scoring.dart';
import '../../utils/error_messages.dart';
import '../../widgets/member_profiles.dart';
import '../../widgets/organizer_guide_sheet.dart';
import '../../widgets/player_avatar.dart';
const _kRadius   = 14.0;
class AddStatsScreen extends StatefulWidget {
  const AddStatsScreen({super.key});
  @override
  State<AddStatsScreen> createState() => _AddStatsScreenState();
}
class _AddStatsScreenState extends State<AddStatsScreen> {
  final String _uid =
      FirebaseAuth.instance.currentUser?.uid ?? '';
  int  _step      = 0;
  bool _isLoading = false;
  Map<String, dynamic>? _selectedEvent;
  String? _selectedTeam;
  Map<String, dynamic>? _selectedPlayer;
  /// The selected player's live avatar, resolved on the previous step. Kept
  /// beside [_selectedPlayer] rather than inside it because that map is read
  /// key-by-key when the stat entry is written.
  String? _selectedPlayerPhotoUrl;
  Set<String> _submittedUids = {};
  /// Each athlete's basketball points already saved for the selected match,
  /// so teammates can't be given more than their team scored between them.
  Map<String, int> _enteredByAthlete = {};
  List<QueryDocumentSnapshot> _pendingMatches = [];
  String? _selectedMatchId;
  bool _openingEvent = false;
  final _ptsCtrl = TextEditingController();
  final _astCtrl = TextEditingController();
  final _rebCtrl = TextEditingController();
  final _stlCtrl = TextEditingController();
  final _blkCtrl = TextEditingController();
  final _toCtrl  = TextEditingController();
  final _killsCtrl  = TextEditingController();
  final _acesCtrl   = TextEditingController();
  final _vAstCtrl   = TextEditingController();
  final _digsCtrl   = TextEditingController();
  final _vBlkCtrl   = TextEditingController();
  final _bPtsCtrl  = TextEditingController();
  final _setsCtrl  = TextEditingController();
  bool  _matchWon  = false;
  final _notesCtrl = TextEditingController();

  // A team-selection step is only inserted for events that actually have
  // team data (created after team assignment was added to event creation)
  // — older events fall back to the flat 3-step flow unchanged.
  bool get _hasTeams => (_selectedEvent?['players'] as List? ?? [])
      .cast<Map<String, dynamic>>().any((p) => p['team'] != null);
  List<String> get _titles => _hasTeams
      ? const ['Select Event', 'Select Team', 'Select Player', 'Enter Stats']
      : const ['Select Event', 'Select Player', 'Enter Stats'];

  @override
  void dispose() {
    for (final c in [
      _ptsCtrl, _astCtrl, _rebCtrl, _stlCtrl, _blkCtrl, _toCtrl,
      _killsCtrl, _acesCtrl, _vAstCtrl, _digsCtrl, _vBlkCtrl,
      _bPtsCtrl, _setsCtrl, _notesCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }
  Map<String, dynamic> _buildStatsData(String sport) {
    if (sport == 'Basketball') {
      return {
        'points':    _n(_ptsCtrl).toInt(),
        'assists':   _n(_astCtrl).toInt(),
        'rebounds':  _n(_rebCtrl).toInt(),
        'steals':    _n(_stlCtrl).toInt(),
        'blocks':    _n(_blkCtrl).toInt(),
        'turnovers': _n(_toCtrl).toInt(),
      };
    } else if (sport == 'Volleyball') {
      return {
        'kills':   _n(_killsCtrl).toInt(),
        'aces':    _n(_acesCtrl).toInt(),
        'assists': _n(_vAstCtrl).toInt(),
        'digs':    _n(_digsCtrl).toInt(),
        'blocks':  _n(_vBlkCtrl).toInt(),
      };
    } else if (sport == 'Badminton') {
      return {
        'pointsScored': _n(_bPtsCtrl).toInt(),
        'setsWon':      _n(_setsCtrl).toInt(),
        'matchWon':     _matchWon,
      };
    }
    return {};
  }
  /// False for a tune-up: its stats are kept, but it awards no points and
  /// moves no one's Elo.
  bool get _ranked =>
      countsTowardRankings(_selectedEvent?['eventType'] as String?);
  int _calcPoints() {
    if (!_ranked) return 0;
    final sport = _selectedEvent?['sport'] as String? ?? '';
    return calcPointsAwarded(sport, _buildStatsData(sport));
  }
  double _n(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;
  Map<String, dynamic>? get _selectedMatch => _pendingMatches
      .where((d) => d.id == _selectedMatchId)
      .firstOrNull
      ?.data() as Map<String, dynamic>?;

  /// The event's players who actually played the selected match, so nobody
  /// who sat out can be given stats for it.
  List<Map<String, dynamic>> get _matchPlayers {
    final all = (_selectedEvent?['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final match = _selectedMatch;
    return match == null ? all : playersInMatch(all, match);
  }

  String get _teamAName =>
      _selectedEvent?['teamAName'] as String? ?? 'Team A';
  String get _teamBName =>
      _selectedEvent?['teamBName'] as String? ?? 'Team B';

  @override
  void initState() {
    super.initState();
    final eventId = (Get.arguments as Map?)?['eventId'] as String?;
    if (eventId != null && eventId.isNotEmpty) _openPresetEvent(eventId);
  }

  /// Opens straight onto one game. Record Match, the event page and Home's
  /// to-do all hand the organizer over this way, so they don't have to find
  /// the game again in a list a tournament may have filled.
  Future<void> _openPresetEvent(String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events').doc(eventId).get();
      final ev = doc.data();
      if (ev != null && mounted) await _openEvent({...ev, 'eventId': doc.id});
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    }
  }

  /// Stats always belong to a recorded match, so the match is settled as
  /// soon as the event is picked: none sends the organizer to record one,
  /// one is taken as is, and several are chosen between.
  Future<void> _openEvent(Map<String, dynamic> ev,
      {bool afterRecording = false}) async {
    if (_openingEvent) return;
    final eventId = ev['eventId'] as String;
    setState(() => _openingEvent = true);
    List<QueryDocumentSnapshot>? matches;
    try {
      matches =
          (await RatingService.pendingMatchesForEvent(eventId).first).docs;
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _openingEvent = false);
    }
    if (matches == null || !mounted) return;

    if (matches.isEmpty) {
      // No pending match on a game with a result means its match already
      // closed: every player's stats are in. Offering Record Match here only
      // led to "Already recorded", which read as stats being impossible.
      if (hasResult(ev)) {
        _showStatsAlreadyIn(ev);
        return;
      }
      // After a trip to Record Match that didn't record anything, stay
      // quiet rather than asking the same question again.
      if (!afterRecording && await _offerRecordMatch()) {
        await Get.toNamed('/matches/record', arguments: {'eventId': eventId});
        if (mounted) await _openEvent(ev, afterRecording: true);
      }
      return;
    }

    final matchId = matches.length == 1
        ? matches.first.id
        : await _chooseMatch(matches);
    if (matchId == null || !mounted) return;
    setState(() {
      _selectedEvent = ev;
      _pendingMatches = matches!;
      _selectedMatchId = matchId;
      _step = 1;
    });
    await _loadSubmitted(matchId);
    // Every stat line is in but the match never closed: the ratings update
    // failed after the last save. Opening the game again is the retry.
    final players = _matchPlayers;
    if (mounted && players.isNotEmpty &&
        _doneCount(players) == players.length) {
      try {
        if (await _maybeFinalizeMatch(matchId)) _showAllStatsIn();
      } catch (e) {
        _snack('Error', friendlyError(e), isError: true);
      }
    }
  }

  int _doneCount(List<Map<String, dynamic>> players) =>
      players.where((p) => _submittedUids.contains(p['uid'])).length;

  /// The end of a game's paperwork, said plainly: the organizer is otherwise
  /// never told that the last save is what updated everyone's rating.
  void _showAllStatsIn() {
    if (!mounted) return;
    final ranked = _ranked;
    final name = _selectedEvent?['name'] as String? ?? 'this game';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('All stats in', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            ranked
                ? "Every player's stats for $name are saved, and their ratings "
                    'have been updated. This game is complete.'
                : "Every player's stats for $name are saved. Tune-ups don't "
                    'change ratings, so this game is now closed.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done', style: TextStyle(
                color: AppTheme.accent, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    // Back to the list of games: this one no longer needs anything.
    setState(() {
      _step = 0;
      _selectedEvent = null;
      _selectedTeam = null;
      _selectedPlayer = null;
      _selectedPlayerPhotoUrl = null;
      _submittedUids = {};
      _pendingMatches = [];
      _selectedMatchId = null;
    });
  }

  /// For a game opened after its stats were finished. Not [_showAllStatsIn],
  /// which reads the selected event and resets the screen, neither of which
  /// applies before a game is opened.
  void _showStatsAlreadyIn(Map<String, dynamic> ev) {
    final name = ev['name'] as String? ?? 'this game';
    final ranked = countsTowardRankings(ev['eventType'] as String?);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('All stats are in', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            ranked
                ? "Every player's stats for $name are already saved, and their "
                    "ratings have been updated. There's nothing left to add "
                    'for this game.'
                : "Every player's stats for $name are already saved. There's "
                    'nothing left to add for this game.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done', style: TextStyle(
                color: AppTheme.accent, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<bool> _offerRecordMatch() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('No recorded match yet', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            'Stats are added for a recorded match. Record the final score '
            "first, then add each player's stats.",
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Not now',
                style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Record Match', style: TextStyle(
                color: AppTheme.accent, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  Future<String?> _chooseMatch(List<QueryDocumentSnapshot> matches) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
              child: Text('Which match are these stats for?', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('This event has more than one recorded match.',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12)),
            ),
            for (final doc in matches)
              Builder(builder: (_) {
                final m = doc.data() as Map<String, dynamic>;
                final a = (m['sideA'] as List? ?? const []).length;
                final b = (m['sideB'] as List? ?? const []).length;
                return ListTile(
                  leading: const Icon(Icons.sports_score_rounded,
                      color: AppTheme.accent),
                  title: Text(
                      matchLabel(m, nameA: _teamAName, nameB: _teamBName),
                      style: TextStyle(color: AppTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('$a vs $b players',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                  onTap: () => Navigator.pop(sheetContext, doc.id),
                );
              }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSubmitted(String matchId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stats')
          .where('matchId', isEqualTo: matchId)
          .get();
      if (mounted) {
        setState(() {
          _submittedUids = snap.docs
              .map((d) => d['athleteId'] as String)
              .toSet();
          _enteredByAthlete = {
            for (final d in snap.docs)
              d['athleteId'] as String:
                  ((d.data()['stats'] as Map?)?['points'] as num?)?.toInt() ??
                      0,
          };
        });
      }
    } catch (_) {}
  }
  void _clearStats() {
    for (final c in [
      _ptsCtrl, _astCtrl, _rebCtrl, _stlCtrl, _blkCtrl, _toCtrl,
      _killsCtrl, _acesCtrl, _vAstCtrl, _digsCtrl, _vBlkCtrl,
      _bPtsCtrl, _setsCtrl, _notesCtrl,
    ]) { c.clear(); }
    _matchWon = false;
  }
  /// The limit on the selected player's points (basketball) or sets
  /// (badminton) in this match; null when the sport isn't capped.
  ScoreCap? get _scoreCap {
    final match = _selectedMatch;
    final uid = _selectedPlayer?['uid'] as String?;
    if (match == null || uid == null) return null;
    return scoreCapFor(
      sport: _selectedEvent?['sport'] as String? ?? '',
      match: match,
      athleteId: uid,
      nameA: _teamAName,
      nameB: _teamBName,
      enteredByAthlete: _enteredByAthlete,
    );
  }

  /// Why the capped stat as typed can't be saved, or null.
  String? get _capError {
    final cap = _scoreCap;
    if (cap == null) return null;
    final ctrl = cap.statKey == 'setsWon' ? _setsCtrl : _ptsCtrl;
    return scoreCapError(cap, _n(ctrl).toInt());
  }

  /// Whether badminton's Win/Loss comes from the recorded result. Only an
  /// event without recorded sides leaves it to the organizer.
  bool get _resultLocked {
    final match = _selectedMatch;
    final uid = _selectedPlayer?['uid'] as String?;
    return match != null && uid != null && matchWonFor(match, uid) != null;
  }

  /// Badminton's Win/Loss and Sets Won follow from the recorded result, so
  /// they're filled in rather than left to be got wrong.
  void _prefillFromResult() {
    if (_selectedEvent?['sport'] != 'Badminton') return;
    final match = _selectedMatch;
    final uid = _selectedPlayer?['uid'] as String?;
    if (match == null || uid == null) return;
    final won = matchWonFor(match, uid);
    if (won != null) _matchWon = won;
    final cap = _scoreCap;
    if (cap != null) _setsCtrl.text = '${cap.teamScore}';
  }

  Future<void> _saveStats() async {
    // The button is disabled while this is set; this is the backstop.
    final capError = _capError;
    if (capError != null) {
      _snack('Check the stats', capError, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final statId     = const Uuid().v4();
      final sport      = _selectedEvent!['sport'] as String;
      final statsData  = _buildStatsData(sport);
      final ranked     = _ranked;
      final points     = ranked ? calcPointsAwarded(sport, statsData) : 0;
      final athleteId  = _selectedPlayer!['uid'] as String;
      final matchId    = _selectedMatchId!;
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('stats').doc(statId),
        {
          'statId':        statId,
          'eventId':       _selectedEvent!['eventId'],
          'eventName':     _selectedEvent!['name'],
          'organizerId':   _uid,
          'athleteId':     athleteId,
          'athleteName':   _selectedPlayer!['fullName'] ?? '',
          'sport':         sport,
          'venue':         _selectedEvent!['venue'] ?? '',
          'eventDate':     _selectedEvent!['eventDate'],
          'stats':         statsData,
          'notes':         _notesCtrl.text.trim(),
          'pointsAwarded': points,
          'matchId':       matchId,
          'createdAt':     FieldValue.serverTimestamp(),
        },
      );
      // A tune-up leaves the athlete's points where they were.
      if (ranked) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(athleteId),
          {'points': FieldValue.increment(points)},
        );
      }
      // NEW: notify the athlete that their stats were recorded.
      // Included in the same batch so it can never be created
      // without the stats/points write actually succeeding.
      await NotificationService.create(
        userId: athleteId,
        type: 'stats_added',
        title: 'Stats recorded',
        body: ranked
            ? 'You earned $points points in ${_selectedEvent!['name']}'
            : 'Your stats from ${_selectedEvent!['name']} were recorded. '
                "Tune-ups don't earn points.",
        relatedId: statId,
        writeBatch: batch,
      );
      await batch.commit();
      // Read before the selection is cleared below.
      final playerName = _selectedPlayer!['fullName'] as String? ?? 'Player';
      if (!mounted) return;
      // Marked done as soon as the stat line is saved, before the ratings
      // step: re-entering a player whose line already exists would save it
      // twice and double their points.
      setState(() {
        _submittedUids.add(athleteId);
        _enteredByAthlete[athleteId] =
            (statsData['points'] as num?)?.toInt() ?? 0;
        // A finished team goes back to the team list, where the other
        // team's progress shows; otherwise on to this team's next player.
        final teamDone = _selectedTeam != null &&
            _matchPlayers
                .where((p) => p['team'] == _selectedTeam)
                .every((p) => _submittedUids.contains(p['uid']));
        _step = _titles.indexOf(teamDone ? 'Select Team' : 'Select Player');
        _selectedPlayer = null;
        _selectedPlayerPhotoUrl = null;
        _clearStats();
      });
      final bool finalized;
      try {
        finalized = await _maybeFinalizeMatch(matchId);
      } catch (e) {
        _snack('Ratings not updated yet',
            "$playerName's stats are saved, but the ratings update didn't go "
                'through. Open this game again in Add Stats to retry.',
            isError: true);
        return;
      }
      if (!mounted) return;
      if (finalized) {
        _showAllStatsIn();
        return;
      }
      Get.snackbar(
        'Stats Saved! ⭐',
        ranked
            ? '$playerName earned $points points'
            : "$playerName's stats are saved",
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText:       AppTheme.accentText,
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
        duration:        const Duration(seconds: 3),
      );
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  /// Once every participant of [matchId] has a stats entry, applies the
  /// Elo/MMR update to their ratings. True when that closed the match.
  Future<bool> _maybeFinalizeMatch(String matchId) async {
    final matchDoc = _pendingMatches.where((d) => d.id == matchId).firstOrNull;
    if (matchDoc == null) return false;
    final matchData = matchDoc.data() as Map<String, dynamic>;
    final participants = [
      ...List<String>.from(matchData['sideA'] as List? ?? []),
      ...List<String>.from(matchData['sideB'] as List? ?? []),
    ];
    final complete = await RatingService.allStatsSubmitted(matchId, participants);
    if (complete) await RatingService.finalizeMatch(matchId, ranked: _ranked);
    return complete;
  }
  void _snack(String t, String m, {bool isError = false}) {
    Get.snackbar(t, m,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: isError ? AppTheme.errorSurface : AppTheme.card,
      colorText:       isError ? AppTheme.errorText : AppTheme.textPrimary,
      margin:          const EdgeInsets.all(16),
      borderRadius:    12,
      duration:        const Duration(seconds: 3));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildProgressBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0), end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key:   ValueKey<int>(_step),
                child: _buildStep(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
  Widget _buildTopBar() {
    final titles = _titles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (_step == 0) { Get.back(); return; }
            setState(() {
              _step--;
              final phase = titles[_step];
              if (phase == 'Select Event') {
                _selectedEvent = null;
                _selectedTeam = null;
                _submittedUids = {};
                _pendingMatches = [];
                _selectedMatchId = null;
              } else if (phase == 'Select Player') {
                _selectedPlayer = null;
                _selectedPlayerPhotoUrl = null;
              }
            });
          },
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
            child: Icon(
              _step > 0 ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
              color: AppTheme.textPrimary, size: _step > 0 ? 16 : 18),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Stats', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          Text(titles[_step], style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ]),
        const Spacer(),
        IconButton(
          tooltip: 'How running a game works',
          onPressed: () => showOrganizerGuideSheet(context),
          icon: Icon(Icons.help_outline_rounded,
              color: AppTheme.sub, size: 20),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent)),
          child: Text('Step ${_step + 1} of ${titles.length}', style: TextStyle(
            color: AppTheme.accentText, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(_titles.length, (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < _titles.length - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: i <= _step ? AppTheme.accent : AppTheme.border,
              borderRadius: BorderRadius.circular(2)),
          ),
        )),
      ),
    );
  }
  Widget _buildStep() {
    switch (_titles[_step]) {
      case 'Select Event':  return _buildStep1();
      case 'Select Team':   return _buildTeamStep();
      case 'Select Player': return _buildStep2();
      default:               return _buildStep3();
    }
  }
  Widget _buildStep1() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: _uid)
          .where('status', isEqualTo: 'upcoming')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5));
        }
        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            subtitle: friendlyError(snapshot.error));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No events yet',
            subtitle: 'Create an event first before adding stats',
            actionLabel: 'Create Event',
            onAction: () => Get.toNamed('/events/create'),
          );
        }
        // Most recently played first: stats are entered after a game, and
        // this used to list oldest first, so the game that had just ended
        // sat at the bottom. See eventsForResults.
        final events = eventsForResults(docs,
            data: (d) => d.data() as Map<String, dynamic>);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: events.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                // Not "Upcoming": finished games are listed here too, and they
                // are the ones stats are for.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Events',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    if (_openingEvent) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(
                          minHeight: 2, color: AppTheme.accent),
                    ],
                  ],
                ),
              );
            }
            final ev   = events[i - 1].data() as Map<String, dynamic>;
            final date = asTimestamp(ev['eventDate']);
            final formattedDate = date != null
                ? DateFormat('MMM dd, yyyy').format(date.toDate())
                : 'No date';

            return GestureDetector(
              onTap: () => _openEvent(ev),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent)),
                    child: const Icon(Icons.emoji_events_outlined,
                        color: AppTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev['name'] as String? ?? '',
                        style: TextStyle(color: AppTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('${ev['sport']} · ${ev['venue']} · $formattedDate',
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                    ],
                  )),
                  Row(children: [
                    Icon(Icons.people_outline, color: AppTheme.muted, size: 14),
                    const SizedBox(width: 4),
                    Text('${ev['playerCount']}',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildTeamStep() {
    final players = _matchPlayers;
    final teamAName = _teamAName;
    final teamBName = _teamBName;
    final teamA = players.where((p) => p['team'] == 'A').toList();
    final teamB = players.where((p) => p['team'] == 'B').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Which team is this stat for?', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _teamCard(teamAName, teamA.length, _doneCount(teamA), 'A'),
        const SizedBox(height: 10),
        _teamCard(teamBName, teamB.length, _doneCount(teamB), 'B'),
      ],
    );
  }
  Widget _teamCard(String name, int count, int done, String team) =>
      GestureDetector(
    onTap: () => setState(() { _selectedTeam = team; _step++; }),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent)),
          child: const Icon(Icons.groups_rounded, color: AppTheme.accent, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
        if (done == count && count > 0) ...[
          Icon(Icons.check_circle, color: AppTheme.successText, size: 16),
          const SizedBox(width: 4),
        ],
        Text('$done of $count done', style: TextStyle(
            color: done == count && count > 0
                ? AppTheme.successText
                : AppTheme.muted,
            fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
      ]),
    ),
  );
  Widget _buildStep2() {
    final allPlayers = _matchPlayers;
    final players = _selectedTeam == null
        ? allPlayers
        : allPlayers.where((p) => p['team'] == _selectedTeam).toList();
    String? teamLabel;
    if (_selectedTeam == 'A') {
      teamLabel = _selectedEvent?['teamAName'] as String? ?? 'Team A';
    } else if (_selectedTeam == 'B') {
      teamLabel = _selectedEvent?['teamBName'] as String? ?? 'Team B';
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent)),
          child: Row(children: [
            const Icon(Icons.emoji_events_outlined, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedEvent?['name'] as String? ?? '',
                  style: TextStyle(color: AppTheme.accentText,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                Text(teamLabel != null
                    ? '${_selectedEvent?['sport']} · $teamLabel · Tap a player to add stats'
                    : '${_selectedEvent?['sport']} · Tap a player to add stats',
                  style: TextStyle(color: AppTheme.sub, fontSize: 11)),
              ])),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(children: [
          Text('${_doneCount(players)} of ${players.length} done',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.successSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.success)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline,
                  color: AppTheme.successText, size: 12),
              const SizedBox(width: 4),
              Text('= Stats submitted',
                style: TextStyle(color: AppTheme.successText, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: players.isEmpty
            ? const _EmptyState(
                icon: Icons.people_outline,
                title: 'No players in this event',
                subtitle: 'Add players when creating the event')
            // The event's `players[]` carries no photo, so the rows read the
            // live user docs — same as the event detail roster these players
            // were picked from.
            : MemberProfilesBuilder(
              uids: players.map((p) => p['uid'] as String? ?? '').toList(),
              builder: (context, profiles) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p       = players[i];
                  final uid     = p['uid'] as String;
                  final done    = _submittedUids.contains(uid);
                  final identity = resolveMemberIdentity(profiles[uid],
                      fallbackName: p['fullName'] as String? ?? '');
                  return GestureDetector(
                    onTap: done ? null : () {
                      setState(() {
                        _selectedPlayer = p;
                        // Held beside the selection rather than injected into
                        // the map, which is the source for the stats write.
                        _selectedPlayerPhotoUrl = identity.photoUrl;
                        _prefillFromResult();
                        _step++;
                      });
                    },
                    child: Opacity(
                      opacity: done ? 0.6 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: done ? AppTheme.cardNested : AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: done ? AppTheme.success : AppTheme.border)),
                        child: Row(children: [
                          PlayerAvatar(
                            name: identity.name,
                            photoUrl: identity.photoUrl,
                            size: 40, radius: 12, fontSize: 13,
                            gradient: done
                                ? [AppTheme.success, const Color(0xFF16A34A)]
                                : null),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(identity.name,
                                style: TextStyle(color: AppTheme.textPrimary,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(p['position'] as String? ?? '',
                                style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                            ],
                          )),
                          done
                              ? Row(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppTheme.successText, size: 18),
                                  const SizedBox(width: 4),
                                  Text('Done', style: TextStyle(
                                    color: AppTheme.successText, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                                ])
                              : const Icon(Icons.add_circle_outline_rounded,
                                  color: AppTheme.accent, size: 22),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
      ),
    ]);
  }
  Widget _buildStep3() {
    final sport = _selectedEvent?['sport'] as String? ?? '';
    return StatefulBuilder(
      builder: (context, setInnerState) {
        final pts = _calcPoints();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
              child: Row(children: [
                PlayerAvatar(
                    name: _selectedPlayer?['fullName'] as String? ?? '',
                    photoUrl: _selectedPlayerPhotoUrl,
                    size: 42, radius: 12, fontSize: 14),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedPlayer?['fullName'] as String? ?? '',
                      style: TextStyle(color: AppTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('${_selectedEvent?['name']} · $sport',
                      style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                  ])),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accent)),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: AppTheme.accent, size: 22),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Points to be Awarded', style: TextStyle(
                    color: AppTheme.sub, fontSize: 11)),
                  Text('$pts',
                    style: TextStyle(color: AppTheme.accentText,
                        fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
                  if (!_ranked) ...[
                    const SizedBox(height: 4),
                    Text('Tune-up — no points or Elo', style: TextStyle(
                      color: AppTheme.sub, fontSize: 11)),
                  ],
                ]),
                const Spacer(),
                Text(sport, style: TextStyle(
                  color: AppTheme.accentText, fontSize: 11,
                  fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 20),
            ..._matchSummary(),
            if (sport == 'Basketball') ..._basketballFields(setInnerState),
            if (sport == 'Volleyball') ..._volleyballFields(setInnerState),
            if (sport == 'Badminton')  ..._badmintonFields(setInnerState),
            ..._capBar(),
            const SizedBox(height: 16),
            _label('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl, maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: _deco('e.g. MVP of the game, strong defense...', Icons.notes_outlined),
            ),
            const SizedBox(height: 28),
            _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2.5))
                : SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _capError == null ? _saveStats : null,
                      child: Text(
                          _ranked ? 'Save Stats (+$pts pts)' : 'Save Stats'),
                    ),
                  ),
          ]),
        );
      },
    );
  }
  /// Fixed rather than a picker: the match was settled when the event was
  /// opened, so every stat line is guaranteed a match.
  List<Widget> _matchSummary() {
    final match = _selectedMatch;
    if (match == null) return const [];
    return [
      _label('Match'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          const Icon(Icons.sports_score_rounded,
              color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(matchLabel(match, nameA: _teamAName, nameB: _teamBName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
    ];
  }
  List<Widget> _basketballFields(StateSetter set) => [
    _label('Statistics'),
    const SizedBox(height: 8),
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _statField(_ptsCtrl, 'Points',     '0', set,
            multiplier: '×1.0', invalid: _capError != null),
        _statField(_astCtrl, 'Assists',    '0', set, multiplier: '×1.5'),
        _statField(_rebCtrl, 'Rebounds',   '0', set, multiplier: '×1.0'),
        _statField(_stlCtrl, 'Steals',     '0', set, multiplier: '×2.0'),
        _statField(_blkCtrl, 'Blocks',     '0', set, multiplier: '×2.0'),
        _statField(_toCtrl,  'Turnovers',  '0', set, multiplier: '−1.0'),
      ],
    ),
  ];
  List<Widget> _volleyballFields(StateSetter set) => [
    _label('Statistics'),
    const SizedBox(height: 8),
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _statField(_killsCtrl, 'Kills',   '0', set, multiplier: '×2.0'),
        _statField(_acesCtrl,  'Aces',    '0', set, multiplier: '×2.0'),
        _statField(_vAstCtrl,  'Assists', '0', set, multiplier: '×1.0'),
        _statField(_digsCtrl,  'Digs',    '0', set, multiplier: '×1.0'),
        _statField(_vBlkCtrl,  'Blocks',  '0', set, multiplier: '×2.0'),
      ],
    ),
  ];
  List<Widget> _badmintonFields(StateSetter set) => [
    _label('Match Result'),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: GestureDetector(
        // Read-only once the recorded result says who won.
        onTap: _resultLocked
            ? null
            : () => set(() { _matchWon = true; setState(() {}); }),
        // "Win", matching the plain "Loss" beside it.
        child: _resultTile('Win', _matchWon, true),
      )),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: _resultLocked
            ? null
            : () => set(() { _matchWon = false; setState(() {}); }),
        child: _resultTile('Loss', !_matchWon, false),
      )),
    ]),
    if (_resultLocked) ...[
      const SizedBox(height: 6),
      Text('Set from the recorded result.',
          style: TextStyle(color: AppTheme.muted, fontSize: 11)),
    ],
    const SizedBox(height: 16),
    _label('Statistics'),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _statField(_setsCtrl, 'Sets Won',       '0', set,
          multiplier: '×3.0', invalid: _capError != null)),
      const SizedBox(width: 10),
      Expanded(child: _statField(_bPtsCtrl, 'Points Scored',  '0', set, multiplier: '×0.5')),
    ]),
  ];
  Widget _resultTile(String label, bool selected, bool isWin) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? (isWin ? AppTheme.successSurface : AppTheme.errorSurface)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: selected
              ? (isWin ? AppTheme.successText : AppTheme.errorText)
              : AppTheme.border,
          width: selected ? 2 : 1.5)),
      child: Center(child: Text(label, style: TextStyle(
        color: selected
            ? (isWin ? AppTheme.successText : AppTheme.errorText)
            : AppTheme.muted,
        fontSize: 14, fontWeight: FontWeight.w700))),
    );
  }
  /// The limit this player's points (or sets) must stay within, and why
  /// once they don't. Its own row, since the grid cells have no room for it.
  List<Widget> _capBar() {
    final cap = _scoreCap;
    if (cap == null) return const [];
    final error = _capError;
    final bad = error != null;
    return [
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bad ? AppTheme.errorSurface : AppTheme.cardNested,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bad ? AppTheme.errorText : AppTheme.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(bad ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: bad ? AppTheme.errorText : AppTheme.muted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error ?? scoreCapHint(cap),
                style: TextStyle(
                    color: bad ? AppTheme.errorText : AppTheme.sub,
                    fontSize: 12, height: 1.35)),
          ),
        ]),
      ),
    ];
  }
  Widget _statField(TextEditingController ctrl, String label,
      String hint, StateSetter set,
      {String multiplier = '', bool invalid = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
            color: invalid ? AppTheme.errorText : AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: AppTheme.sub,
              fontSize: 10, fontWeight: FontWeight.w600)),
          if (multiplier.isNotEmpty)
            Text(multiplier, style: TextStyle(color: AppTheme.muted, fontSize: 9)),
        ]),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => set(() => setState(() {})),
          style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.muted, fontSize: 18),
            border: InputBorder.none, isDense: true,
            contentPadding: const EdgeInsets.only(top: 4)),
        ),
      ]),
    );
  }
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(text, style: TextStyle(
      color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
  );
  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
    prefixIcon: Icon(icon, color: AppTheme.muted, size: 18),
    filled: true, fillColor: AppTheme.card,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
  );
}
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final String?  actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent)),
            child: Icon(icon, color: AppTheme.accent, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 180, height: 46,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!)),
            ),
          ],
        ]),
      ),
    );
  }
}