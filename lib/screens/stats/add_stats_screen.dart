// lib/screens/stats/add_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const _kRadius   = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);

// Points formula per sport
// Basketball: pts×1 + ast×1.5 + reb×1 + stl×2 + blk×2 - to×1
// Volleyball:  kills×2 + aces×2 + ast×1 + digs×1 + blk×2
// Badminton:   win×10 + sets×3 + pts×0.5

// ─────────────────────────────────────────────
// AddStatsScreen
// ─────────────────────────────────────────────

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

  // Selected data across steps
  Map<String, dynamic>? _selectedEvent;
  Map<String, dynamic>? _selectedPlayer;

  // Stats already submitted for selected event
  Set<String> _submittedUids = {};

  // ── Basketball ────────────────────────────
  final _ptsCtrl = TextEditingController();
  final _astCtrl = TextEditingController();
  final _rebCtrl = TextEditingController();
  final _stlCtrl = TextEditingController();
  final _blkCtrl = TextEditingController();
  final _toCtrl  = TextEditingController();

  // ── Volleyball ────────────────────────────
  final _killsCtrl  = TextEditingController();
  final _acesCtrl   = TextEditingController();
  final _vAstCtrl   = TextEditingController();
  final _digsCtrl   = TextEditingController();
  final _vBlkCtrl   = TextEditingController();

  // ── Badminton ─────────────────────────────
  final _bPtsCtrl  = TextEditingController();
  final _setsCtrl  = TextEditingController();
  bool  _matchWon  = false;

  // Notes
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _ptsCtrl, _astCtrl, _rebCtrl, _stlCtrl, _blkCtrl, _toCtrl,
      _killsCtrl, _acesCtrl, _vAstCtrl, _digsCtrl, _vBlkCtrl,
      _bPtsCtrl, _setsCtrl, _notesCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Points calculation ────────────────────

  double _calcPoints() {
    final sport = _selectedEvent?['sport'] as String? ?? '';
    switch (sport) {
      case 'Basketball':
        return (_n(_ptsCtrl) * 1.0)
             + (_n(_astCtrl) * 1.5)
             + (_n(_rebCtrl) * 1.0)
             + (_n(_stlCtrl) * 2.0)
             + (_n(_blkCtrl) * 2.0)
             - (_n(_toCtrl)  * 1.0);
      case 'Volleyball':
        return (_n(_killsCtrl) * 2.0)
             + (_n(_acesCtrl)  * 2.0)
             + (_n(_vAstCtrl)  * 1.0)
             + (_n(_digsCtrl)  * 1.0)
             + (_n(_vBlkCtrl)  * 2.0);
      case 'Badminton':
        return (_matchWon ? 10.0 : 0.0)
             + (_n(_setsCtrl) * 3.0)
             + (_n(_bPtsCtrl) * 0.5);
      default:
        return 0;
    }
  }

  double _n(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  // ── Load already-submitted UIDs for event ─

  Future<void> _loadSubmitted(String eventId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stats')
          .where('eventId', isEqualTo: eventId)
          .get();
      if (mounted) {
        setState(() {
          _submittedUids = snap.docs
              .map((d) => d['athleteId'] as String)
              .toSet();
        });
      }
    } catch (_) {}
  }

  // ── Clear stat fields ─────────────────────

  void _clearStats() {
    for (final c in [
      _ptsCtrl, _astCtrl, _rebCtrl, _stlCtrl, _blkCtrl, _toCtrl,
      _killsCtrl, _acesCtrl, _vAstCtrl, _digsCtrl, _vBlkCtrl,
      _bPtsCtrl, _setsCtrl, _notesCtrl,
    ]) { c.clear(); }
    _matchWon = false;
  }

  // ── Save stats ────────────────────────────

  Future<void> _saveStats() async {
    setState(() => _isLoading = true);
    try {
      final statId     = const Uuid().v4();
      // Round to int so Firestore always stores as int, not double
      final points     = _calcPoints().clamp(0, double.infinity).round();
      final sport      = _selectedEvent!['sport'] as String;
      final athleteId  = _selectedPlayer!['uid'] as String;

      Map<String, dynamic> statsData = {};
      if (sport == 'Basketball') {
        statsData = {
          'points':    _n(_ptsCtrl).toInt(),
          'assists':   _n(_astCtrl).toInt(),
          'rebounds':  _n(_rebCtrl).toInt(),
          'steals':    _n(_stlCtrl).toInt(),
          'blocks':    _n(_blkCtrl).toInt(),
          'turnovers': _n(_toCtrl).toInt(),
        };
      } else if (sport == 'Volleyball') {
        statsData = {
          'kills':   _n(_killsCtrl).toInt(),
          'aces':    _n(_acesCtrl).toInt(),
          'assists': _n(_vAstCtrl).toInt(),
          'digs':    _n(_digsCtrl).toInt(),
          'blocks':  _n(_vBlkCtrl).toInt(),
        };
      } else {
        statsData = {
          'pointsScored': _n(_bPtsCtrl).toInt(),
          'setsWon':      _n(_setsCtrl).toInt(),
          'matchWon':     _matchWon,
        };
      }

      final batch = FirebaseFirestore.instance.batch();

      // Write stats document
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
          'createdAt':     FieldValue.serverTimestamp(),
        },
      );

      // Increment athlete's total points
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(athleteId),
        {'points': FieldValue.increment(points)},
      );

      await batch.commit();

      if (!mounted) return;

      // Mark as submitted and go back to player list
      setState(() {
        _submittedUids.add(athleteId);
        _step = 1;
        _selectedPlayer = null;
        _clearStats();
      });

      Get.snackbar(
        'Stats Saved! ⭐',
        '${_selectedPlayer?['fullName'] ?? 'Player'} earned $points points',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText:       AppTheme.accentText,
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
        duration:        const Duration(seconds: 3),
      );
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String t, String m, {bool isError = false}) {
    Get.snackbar(t, m,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
      colorText:       isError ? _kErrorRed : AppTheme.textPrimary,
      margin:          const EdgeInsets.all(16),
      borderRadius:    12,
      duration:        const Duration(seconds: 3));
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

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
    final titles = ['Select Event', 'Select Player', 'Enter Stats'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (_step == 0) { Get.back(); return; }
            setState(() {
              _step--;
              if (_step == 0) { _selectedEvent = null; _submittedUids = {}; }
              if (_step == 1) _selectedPlayer = null;
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent)),
          child: Text('Step ${_step + 1} of 3', style: TextStyle(
            color: AppTheme.accentText, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: i <= _step ? AppTheme.accent : AppTheme.border,
              borderRadius: BorderRadius.circular(2)),
          ),
        )),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:  return _buildStep1();
      case 1:  return _buildStep2();
      default: return _buildStep3();
    }
  }

  // ─────────────────────────────────────────
  // Step 1 — Select Event
  // ─────────────────────────────────────────

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
            subtitle: snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No upcoming events',
            subtitle: 'Create an event first before adding stats',
            actionLabel: 'Create Event',
            onAction: () => Get.toNamed('/events/create'),
          );
        }

        // Sort client-side by eventDate
        final events = docs.toList()..sort((a, b) {
          final aT = (a.data() as Map)['eventDate'] as Timestamp?;
          final bT = (b.data() as Map)['eventDate'] as Timestamp?;
          if (aT == null || bT == null) return 0;
          return aT.compareTo(bT);
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: events.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Your Upcoming Events',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              );
            }
            final ev   = events[i - 1].data() as Map<String, dynamic>;
            final date = ev['eventDate'] as Timestamp?;
            final formattedDate = date != null
                ? DateFormat('MMM dd, yyyy').format(date.toDate())
                : 'No date';

            return GestureDetector(
              onTap: () async {
                setState(() { _selectedEvent = ev; _step = 1; });
                await _loadSubmitted(ev['eventId'] as String);
              },
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

  // ─────────────────────────────────────────
  // Step 2 — Select Player
  // ─────────────────────────────────────────

  Widget _buildStep2() {
    final players = (_selectedEvent?['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return Column(children: [
      // Event info header
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
                Text('${_selectedEvent?['sport']} · Tap a player to add stats',
                  style: TextStyle(color: AppTheme.sub, fontSize: 11)),
              ])),
          ]),
        ),
      ),

      // Legend
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(children: [
          Text('${players.length} Players',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3020),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.success)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 12),
              const SizedBox(width: 4),
              Text('= Stats submitted',
                style: TextStyle(color: AppTheme.success, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),

      // Player list
      Expanded(
        child: players.isEmpty
            ? _EmptyState(
                icon: Icons.people_outline,
                title: 'No players in this event',
                subtitle: 'Add players when creating the event')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p       = players[i];
                  final uid     = p['uid'] as String;
                  final done    = _submittedUids.contains(uid);
                  final initials = _getInitials(p['fullName'] as String? ?? '');

                  return GestureDetector(
                    onTap: done ? null : () {
                      setState(() { _selectedPlayer = p; _step = 2; });
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
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: done
                                    ? [AppTheme.success, const Color(0xFF16A34A)]
                                    : [AppTheme.accent, AppTheme.accent2]),
                              borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(initials, style: const TextStyle(
                              color: AppTheme.buttonFg, fontSize: 13,
                              fontWeight: FontWeight.w800))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['fullName'] as String? ?? '',
                                style: TextStyle(color: AppTheme.textPrimary,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(p['position'] as String? ?? '',
                                style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                            ],
                          )),
                          done
                              ? Row(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppTheme.success, size: 18),
                                  const SizedBox(width: 4),
                                  Text('Done', style: TextStyle(
                                    color: AppTheme.success, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                                ])
                              : Icon(Icons.add_circle_outline_rounded,
                                  color: AppTheme.accent, size: 22),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ─────────────────────────────────────────
  // Step 3 — Enter Stats
  // ─────────────────────────────────────────

  Widget _buildStep3() {
    final sport = _selectedEvent?['sport'] as String? ?? '';

    return StatefulBuilder(
      builder: (context, setInnerState) {
        final pts = _calcPoints().clamp(0, double.infinity).round();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Player & event info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                    _getInitials(_selectedPlayer?['fullName'] as String? ?? ''),
                    style: const TextStyle(color: AppTheme.buttonFg,
                        fontSize: 14, fontWeight: FontWeight.w800))),
                ),
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

            // Live points preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accent)),
              child: Row(children: [
                const Text('⭐', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Points to be Awarded', style: TextStyle(
                    color: AppTheme.sub, fontSize: 11)),
                  Text('$pts',
                    style: TextStyle(color: AppTheme.accentText,
                        fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
                ]),
                const Spacer(),
                Text(sport, style: TextStyle(
                  color: AppTheme.accentText, fontSize: 11,
                  fontWeight: FontWeight.w700)),
              ]),
            ),

            const SizedBox(height: 20),

            // Sport-specific stat fields
            if (sport == 'Basketball') ..._basketballFields(setInnerState),
            if (sport == 'Volleyball') ..._volleyballFields(setInnerState),
            if (sport == 'Badminton')  ..._badmintonFields(setInnerState),

            const SizedBox(height: 16),

            // Notes
            _label('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl, maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: _deco('e.g. MVP of the game, strong defense...', Icons.notes_outlined),
            ),

            const SizedBox(height: 28),

            // Save button
            _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2.5))
                : SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _saveStats,
                      child: Text('Save Stats (+$pts pts)'),
                    ),
                  ),
          ]),
        );
      },
    );
  }

  // ── Sport stat fields ─────────────────────

  List<Widget> _basketballFields(StateSetter set) => [
    _label('Statistics'),
    const SizedBox(height: 8),
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _statField(_ptsCtrl, 'Points',     '0', set, multiplier: '×1.0'),
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
        onTap: () => set(() { _matchWon = true; setState(() {}); }),
        child: _resultTile('Win 🏆', _matchWon, true),
      )),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => set(() { _matchWon = false; setState(() {}); }),
        child: _resultTile('Loss', !_matchWon, false),
      )),
    ]),
    const SizedBox(height: 16),
    _label('Statistics'),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _statField(_setsCtrl, 'Sets Won',       '0', set, multiplier: '×3.0')),
      const SizedBox(width: 10),
      Expanded(child: _statField(_bPtsCtrl, 'Points Scored',  '0', set, multiplier: '×0.5')),
    ]),
  ];

  Widget _resultTile(String label, bool selected, bool isWin) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? (isWin ? const Color(0xFF0D2E20) : const Color(0xFF2A1010))
            : AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: selected
              ? (isWin ? AppTheme.success : _kErrorRed)
              : AppTheme.border,
          width: selected ? 2 : 1.5)),
      child: Center(child: Text(label, style: TextStyle(
        color: selected
            ? (isWin ? AppTheme.success : _kErrorRed)
            : AppTheme.muted,
        fontSize: 14, fontWeight: FontWeight.w700))),
    );
  }

  Widget _statField(TextEditingController ctrl, String label,
      String hint, StateSetter set, {String multiplier = ''}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: AppTheme.border)),
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

  // ── Helpers ───────────────────────────────

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

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────
// Empty State Widget
// ─────────────────────────────────────────────

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