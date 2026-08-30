// lib/screens/events/record_match_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../services/rating_service.dart';
import '../../utils/error_messages.dart';

const _kSideA = 'A';
const _kSideB = 'B';

/// Lets a coach/organizer record who played whom at an event: splits the
/// roster into two sides and enters the final score. This becomes the
/// match record that RatingService.finalizeMatch later applies Elo
/// updates against, once every participant's stats are in.
class RecordMatchScreen extends StatefulWidget {
  const RecordMatchScreen({super.key});
  @override
  State<RecordMatchScreen> createState() => _RecordMatchScreenState();
}

class _RecordMatchScreenState extends State<RecordMatchScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  Map<String, dynamic>? _selectedEvent;

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

  bool get _canSubmit {
    final sideA = _sides.entries.where((e) => e.value == _kSideA);
    final sideB = _sides.entries.where((e) => e.value == _kSideB);
    if (sideA.isEmpty || sideB.isEmpty) return false;
    final scoreA = int.tryParse(_scoreACtrl.text.trim());
    final scoreB = int.tryParse(_scoreBCtrl.text.trim());
    if (scoreA == null || scoreB == null) return false;
    return scoreA != scoreB;
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

    setState(() => _isSaving = true);
    try {
      await RatingService.recordMatch(
        eventId: _selectedEvent!['eventId'] as String,
        sport: _selectedEvent!['sport'] as String,
        sideA: sideA,
        sideB: sideB,
        scoreA: scoreA,
        scoreB: scoreB,
        recordedBy: _uid,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: _selectedEvent == null ? _buildEventPicker() : _buildSidesForm(),
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
            if (_selectedEvent == null) {
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
              _selectedEvent == null ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: _selectedEvent == null ? 18 : 16),
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
              onTap: () => setState(() {
                _selectedEvent = ev;
                // Prefill from each player's team, assigned at event
                // creation, so the organizer isn't re-splitting the same
                // roster from scratch every time a match is recorded.
                // Any individual player can still be flipped below.
                _sides.clear();
                for (final p in (ev['players'] as List? ?? [])
                    .cast<Map<String, dynamic>>()) {
                  final team = p['team'] as String?;
                  if (team == _kSideA || team == _kSideB) {
                    _sides[p['uid'] as String] = team!;
                  }
                }
              }),
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
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Record Match'),
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
            contentPadding: EdgeInsets.only(top: 4)),
        ),
      ]),
    );
  }
}
