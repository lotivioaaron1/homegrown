// lib/screens/leaderboard/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const List<String> _kFilters = ['All', 'Basketball', 'Volleyball', 'Badminton'];

// ─────────────────────────────────────────────
// LeaderboardScreen
// ─────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final String _uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _filter     = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildFilterRow(),
          Expanded(child: _buildList()),
        ]),
      ),
    );
  }

  // ── Top bar ───────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Text('Leaderboard', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent)),
          child: Text('Legazpi City', style: TextStyle(
            color: AppTheme.accentText, fontSize: 10,
            fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Filter row ────────────────────────────

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: _kFilters.map((f) {
          final sel = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppTheme.accentSurface : AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? AppTheme.accent : AppTheme.border,
                  width: sel ? 2 : 1.5)),
              child: Text(
                f == 'All' ? 'All Sports'
                  : f == 'Basketball' ? '🏀 Basketball'
                  : f == 'Volleyball' ? '🏐 Volleyball'
                  : '🏸 Badminton',
                style: TextStyle(
                  color: sel ? AppTheme.accentText : AppTheme.muted,
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Main list ─────────────────────────────

  Widget _buildList() {
    // Build query — filter by sport if not "All"
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'athlete');

    if (_filter != 'All') {
      query = query.where('primarySports', arrayContains: _filter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5));
        }
        if (snapshot.hasError) {
          return _buildEmpty(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            subtitle: snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            icon: Icons.emoji_events_outlined,
            title: 'No athletes yet',
            subtitle: _filter == 'All'
                ? 'Register athletes to see rankings'
                : 'No $_filter athletes found');
        }

        // Sort by points descending — client side
        final athletes = docs.map((d) => d.data() as Map<String, dynamic>).toList()
          ..sort((a, b) {
            final aP = _toInt(a['points']);
            final bP = _toInt(b['points']);
            return bP.compareTo(aP);
          });



        final top3  = athletes.take(3).toList();
        final rest  = athletes.length > 3 ? athletes.sublist(3) : <Map<String, dynamic>>[];
        final myRank = athletes.indexWhere((a) => a['uid'] == _uid) + 1;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(_uid).snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final role     = userData['role'] as String? ?? 'athlete';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ── Podium ──────────────────
                if (top3.isNotEmpty) _buildPodium(top3, role),
                const SizedBox(height: 20),

                // ── My rank banner (athlete only) ──
                if (role == 'athlete' && myRank > 3 && myRank > 0) ...[
                  _buildMyRankBanner(myRank, athletes[myRank - 1]),
                  const SizedBox(height: 16),
                ],

                // ── Rest of list ────────────
                if (rest.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      role == 'coach' ? 'TAP ATHLETE TO SCOUT' : 'FULL RANKINGS',
                      style: TextStyle(color: AppTheme.muted, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border)),
                    child: Column(
                      children: rest.asMap().entries.map((e) {
                        final rank    = e.key + 4;
                        final athlete = e.value;
                        final isLast  = e.key == rest.length - 1;
                        final isMe    = athlete['uid'] == _uid;
                        return _buildRow(
                          rank: rank,
                          athlete: athlete,
                          isLast: isLast,
                          isMe: isMe,
                          isCoach: role == 'coach');
                      }).toList(),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // ── Podium ────────────────────────────────

  Widget _buildPodium(List<Map<String, dynamic>> top3, String role) {
    final first  = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1  ? top3[1] : null;
    final third  = top3.length > 2  ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        // Crown + label
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('👑', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('Top Athletes', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),

        // Podium columns: 2nd, 1st, 3rd
        Row(crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (second != null) _podiumItem(second, 2, 70),
            const SizedBox(width: 8),
            if (first  != null) _podiumItem(first,  1, 95),
            const SizedBox(width: 8),
            if (third  != null) _podiumItem(third,  3, 55),
          ],
        ),
      ]),
    );
  }

  Widget _podiumItem(Map<String, dynamic> athlete, int rank, double barH) {
    final pts    = _toInt(athlete['points']);
    final isMe   = athlete['uid'] == _uid;
    final colors = {
      1: [const Color(0xFFFFB800), const Color(0xFF2E1F00)],
      2: [const Color(0xFF8888AA), const Color(0xFF1E1E35)],
      3: [const Color(0xFFCC9500), const Color(0xFF1A1200)],
    };
    final accentColor = colors[rank]![0];
    final bgColor     = colors[rank]![1];

    return Column(children: [
      // Avatar
      Container(
        width: rank == 1 ? 52 : 40,
        height: rank == 1 ? 52 : 40,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          border: isMe ? Border.all(color: AppTheme.accent, width: 2.5) : null),
        child: Center(child: Text(
          _initials(athlete['fullName'] as String? ?? ''),
          style: TextStyle(
            color: AppTheme.buttonFg,
            fontSize: rank == 1 ? 16 : 13,
            fontWeight: FontWeight.w800))),
      ),
      const SizedBox(height: 4),
      SizedBox(width: 60, child: Text(
        _firstName(athlete['fullName'] as String? ?? ''),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe ? AppTheme.accent : AppTheme.textPrimary,
          fontSize: 10, fontWeight: FontWeight.w600))),
      Text('$pts pts', style: TextStyle(
        color: accentColor, fontSize: 10, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      // Bar
      Container(
        width: rank == 1 ? 60 : 50,
        height: barH,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          border: Border.all(color: accentColor)),
        child: Center(child: Text('#$rank', style: TextStyle(
          color: accentColor, fontSize: 11, fontWeight: FontWeight.w800))),
      ),
    ]);
  }

  // ── My rank banner ────────────────────────

  Widget _buildMyRankBanner(int rank, Map<String, dynamic> athlete) {
    final pts = _toInt(athlete['points']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent, width: 1.5)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('$rank', style: const TextStyle(
            color: AppTheme.buttonFg, fontSize: 14, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Rank', style: TextStyle(
              color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w600)),
            Text('$pts points earned so far', style: TextStyle(
              color: AppTheme.accentText, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
        const Text('⭐', style: TextStyle(fontSize: 22)),
      ]),
    );
  }

  // ── List row ──────────────────────────────

  Widget _buildRow({
    required int rank,
    required Map<String, dynamic> athlete,
    required bool isLast,
    required bool isMe,
    required bool isCoach,
  }) {
    final pts      = _toInt(athlete['points']);
    final position = athlete['position']    as String? ?? '';
    final barangay = athlete['barangay']    as String? ?? '';
    final isOpen   = athlete['openToRecruitment'] as bool? ?? false;

    return GestureDetector(
      onTap: isCoach ? () => _showAthleteProfile(athlete) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? AppTheme.accentSurface.withValues(alpha: 0.5) : Colors.transparent,
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            // Rank
            SizedBox(width: 24, child: Text('$rank', style: TextStyle(
              color: isMe ? AppTheme.accent : AppTheme.muted,
              fontSize: 13, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: isMe
                      ? [AppTheme.accent, AppTheme.accent2]
                      : [AppTheme.cardNested, AppTheme.cardNested]),
                borderRadius: BorderRadius.circular(10),
                border: isMe ? Border.all(color: AppTheme.accent, width: 1.5) : null),
              child: Center(child: Text(
                _initials(athlete['fullName'] as String? ?? ''),
                style: TextStyle(
                  color: isMe ? AppTheme.buttonFg : AppTheme.muted,
                  fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            // Name + sub
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    isMe ? 'You' : (athlete['fullName'] as String? ?? ''),
                    style: TextStyle(
                      color: isMe ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('YOU', style: TextStyle(
                        color: AppTheme.buttonFg, fontSize: 8,
                        fontWeight: FontWeight.w800))),
                  ],
                ]),
                Text(
                  [if (position.isNotEmpty) position, if (barangay.isNotEmpty) barangay]
                      .join(' · '),
                  style: TextStyle(color: AppTheme.sub, fontSize: 10),
                  overflow: TextOverflow.ellipsis),
              ])),
            // Points + scout badge
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$pts', style: TextStyle(
                color: isMe ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w800)),
              if (isCoach)
                Text(isOpen ? '✓ Open' : '✕ Closed',
                  style: TextStyle(
                    color: isOpen ? AppTheme.success : AppTheme.muted,
                    fontSize: 9, fontWeight: FontWeight.w700)),
              if (!isCoach && isMe)
                Text('pts', style: TextStyle(
                  color: AppTheme.muted, fontSize: 9)),
            ]),
            if (isCoach) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 18),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Athlete profile bottom sheet (Coach) ──

  void _showAthleteProfile(Map<String, dynamic> athlete) {
    final pts      = _toInt(athlete['points']);
    final position = athlete['position']          as String? ?? '—';
    final barangay = athlete['barangay']          as String? ?? '—';
    final sports   = (athlete['primarySports'] as List?)
        ?.map((e) => e.toString()).join(', ') ?? '—';
    final years    = athlete['yearsOfPlaying']    as String? ?? '—';
    final isOpen   = athlete['openToRecruitment'] as bool? ?? false;
    final bio      = athlete['bio']               as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppTheme.accent, AppTheme.accent2]),
                  borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(
                  _initials(athlete['fullName'] as String? ?? ''),
                  style: const TextStyle(color: AppTheme.buttonFg,
                      fontSize: 18, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(athlete['fullName'] as String? ?? '',
                    style: TextStyle(color: AppTheme.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('$position · $barangay',
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ])),
              // Points badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent)),
                child: Column(children: [
                  Text('$pts', style: TextStyle(
                    color: AppTheme.accentText, fontSize: 20,
                    fontWeight: FontWeight.w900)),
                  Text('pts', style: TextStyle(
                    color: AppTheme.muted, fontSize: 9)),
                ]),
              ),
            ]),

            const SizedBox(height: 20),
            Divider(color: AppTheme.border),
            const SizedBox(height: 12),

            // Stats grid
            Row(children: [
              _profileStat('Sport', sports),
              const SizedBox(width: 12),
              _profileStat('Experience', years),
              const SizedBox(width: 12),
              _profileStat('Barangay', barangay),
            ]),

            const SizedBox(height: 16),

            // Recruitment status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOpen
                    ? const Color(0xFF0D2E20)
                    : AppTheme.cardNested,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen ? AppTheme.success : AppTheme.border)),
              child: Row(children: [
                Icon(isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isOpen ? AppTheme.success : AppTheme.muted, size: 20),
                const SizedBox(width: 10),
                Text(
                  isOpen
                      ? 'Open to recruitment — available to join a team'
                      : 'Not currently open to recruitment',
                  style: TextStyle(
                    color: isOpen ? AppTheme.success : AppTheme.muted,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),

            if (bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Bio', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(bio, style: TextStyle(
                color: AppTheme.sub, fontSize: 13, height: 1.6)),
            ],

            const SizedBox(height: 24),

            // Close
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                child: Text('Close', style: TextStyle(
                  color: AppTheme.sub, fontSize: 15,
                  fontWeight: FontWeight.w600))),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _profileStat(String label, String value) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardNested,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Text(label, style: TextStyle(
          color: AppTheme.muted, fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 11,
          fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
      ]),
    ));
  }

  // ── Empty state ───────────────────────────

  Widget _buildEmpty({required IconData icon,
      required String title, required String subtitle}) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent)),
          child: Icon(icon, color: AppTheme.accent, size: 32)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(
          color: AppTheme.sub, fontSize: 13, height: 1.5)),
      ]),
    ));
  }

  // ── Helpers ───────────────────────────────

  int _toInt(dynamic val) {
    if (val is int)    return val;
    if (val is double) return val.toInt();
    return 0;
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }
}