// lib/screens/leaderboard/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/rating_service.dart';
import '../../utils/elo_calculator.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../utils/error_messages.dart';

const List<String> _kFilters = ['All', 'Basketball', 'Volleyball', 'Badminton'];

/// Hard ceiling on how many athlete documents one leaderboard view will read.
///
/// The ranking can't be pushed into the query: the "All" view sorts on `points`,
/// but a sport filter sorts on `ratings.<sport>` and treats a missing rating as
/// [kStartingRating]. Firestore's `orderBy` drops documents that lack the field
/// entirely, so ordering server-side would silently hide every athlete who has
/// never been rated in that sport. Ranking therefore stays client-side, and this
/// bounds what it costs.
///
/// Legazpi has nowhere near this many registered athletes, so in practice the
/// cap never binds and the ranking is exact. Past it, the board becomes "top
/// 200-ish" rather than wrong — an acceptable trade for a bounded bill.
const int _kMaxRankedAthletes = 200;

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _filter = 'All';

  String? _streamedFilter;
  Stream<QuerySnapshot>? _athletesStream;

  /// Held across rebuilds rather than rebuilt inside `build()`. A freshly
  /// constructed `snapshots()` is a new stream identity, so StreamBuilder would
  /// tear down its subscription and re-read the whole result set on every
  /// filter tap and every pull-to-refresh. Only a filter change should cost a
  /// new query.
  Stream<QuerySnapshot> _athleteStream() {
    if (_athletesStream != null && _streamedFilter == _filter) {
      return _athletesStream!;
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'athlete');

    if (_filter != 'All') {
      query = query.where('primarySports', arrayContains: _filter);
    }

    _streamedFilter = _filter;
    return _athletesStream = query.limit(_kMaxRankedAthletes).snapshots();
  }

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
            child: Icon(LucideIcons.chevronLeft,
                color: AppTheme.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text('Leaderboard', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
      ]),
    );
  }

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

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _athleteStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5));
        }
        if (snapshot.hasError) {
          return _buildEmpty(
            icon: LucideIcons.alertCircle,
            title: 'Something went wrong',
            subtitle: friendlyError(snapshot.error));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            icon: LucideIcons.trophy,
            title: 'No athletes yet',
            subtitle: _filter == 'All'
                ? 'Register athletes to see rankings'
                : 'No $_filter athletes found');
        }

        final athletes = docs.map((d) => d.data() as Map<String, dynamic>).toList()
          ..sort((a, b) => _rankValue(b).compareTo(_rankValue(a)));

        final top3 = athletes.take(3).toList();
        final rest = athletes.length > 3 ? athletes.sublist(3) : <Map<String, dynamic>>[];
        final myRank = athletes.indexWhere((a) => a['uid'] == _uid) + 1;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(_uid).snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final role = userData['role'] as String? ?? 'athlete';

            return RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (top3.isNotEmpty) _buildPodium(top3, role),
                  const SizedBox(height: 20),
                  if (role == 'athlete' && myRank > 3 && myRank > 0) ...[
                    _buildMyRankBanner(myRank, athletes[myRank - 1]),
                    const SizedBox(height: 16),
                  ],
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
                          final rank = e.key + 4;
                          final athlete = e.value;
                          final isLast = e.key == rest.length - 1;
                          final isMe = athlete['uid'] == _uid;
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3, String role) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(LucideIcons.crown, color: AppTheme.accent, size: 16),
          const SizedBox(width: 6),
          Text('Top Athletes', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (second != null) _podiumItem(second, 2, 70),
            const SizedBox(width: 8),
            if (first != null) _podiumItem(first, 1, 95),
            const SizedBox(width: 8),
            if (third != null) _podiumItem(third, 3, 55),
          ],
        ),
      ]),
    );
  }

  Widget _podiumItem(Map<String, dynamic> athlete, int rank, double barH) {
    final pts = _rankValue(athlete);
    final isMe = athlete['uid'] == _uid;
    final name = _displayName(athlete);
    final photoUrl = athlete['photoUrl'] as String?;
    final colors = {
      1: [const Color(0xFFFFB800), const Color(0xFF2E1F00)],
      2: [const Color(0xFFB8BCC8), const Color(0xFF1E1E28)],
      3: [const Color(0xFFCD7F32), const Color(0xFF2E1D0F)],
    };
    final accentColor = colors[rank]![0];
    final bgColor = colors[rank]![1];
    final size = rank == 1 ? 52.0 : 40.0;

    return Column(children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
          border: isMe ? Border.all(color: AppTheme.accent, width: 2.5) : null),
        child: ClipOval(
          child: photoUrl != null && photoUrl.isNotEmpty
              ? Image.network(photoUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(child: Text(
                      _initials(name),
                      style: TextStyle(color: AppTheme.buttonFg,
                          fontSize: rank == 1 ? 16 : 13,
                          fontWeight: FontWeight.w800))))
              : Center(child: Text(_initials(name),
                  style: TextStyle(color: AppTheme.buttonFg,
                      fontSize: rank == 1 ? 16 : 13,
                      fontWeight: FontWeight.w800))),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(width: 60, child: Text(
        _firstName(name),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe ? AppTheme.accent : AppTheme.textPrimary,
          fontSize: 10, fontWeight: FontWeight.w600))),
      Text('$pts $_unitLabel', style: TextStyle(
        color: accentColor, fontSize: 10, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
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

  Widget _buildMyRankBanner(int rank, Map<String, dynamic> athlete) {
    final pts = _rankValue(athlete);
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
            Text(
              _filter == 'All' ? '$pts points earned so far' : '$pts $_unitLabel rating',
              style: TextStyle(
              color: AppTheme.accentText, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
        Icon(LucideIcons.star, color: AppTheme.accent, size: 20),
      ]),
    );
  }

  Widget _buildRow({
    required int rank,
    required Map<String, dynamic> athlete,
    required bool isLast,
    required bool isMe,
    required bool isCoach,
  }) {
    final pts = _rankValue(athlete);
    final position = athlete['position'] as String? ?? '';
    final barangay = athlete['barangay'] as String? ?? '';
    final isOpen = athlete['openToRecruitment'] as bool? ?? false;
    final name = _displayName(athlete);
    final photoUrl = athlete['photoUrl'] as String?;

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
            SizedBox(width: 24, child: Text('$rank', style: TextStyle(
              color: isMe ? AppTheme.accent : AppTheme.muted,
              fontSize: 13, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(photoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text(
                            _initials(name),
                            style: TextStyle(
                                color: isMe ? AppTheme.buttonFg : AppTheme.muted,
                                fontSize: 12, fontWeight: FontWeight.w800))))
                    : Center(child: Text(_initials(name),
                        style: TextStyle(
                            color: isMe ? AppTheme.buttonFg : AppTheme.muted,
                            fontSize: 12, fontWeight: FontWeight.w800))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    isMe ? 'You' : name,
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
                Text(_unitLabel, style: TextStyle(
                  color: AppTheme.muted, fontSize: 9)),
            ]),
            if (isCoach) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 18),
            ],
          ]),
        ),
      ),
    );
  }

  void _showAthleteProfile(Map<String, dynamic> athlete) {
    final athleteId = athlete['uid'] as String? ?? '';
    showAthleteProfileSheet(context, athleteId: athleteId);
  }

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

  int _toInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    return 0;
  }

  /// The number this leaderboard ranks and displays by: the sport's Elo
  /// rating when filtered to a sport, raw cumulative points otherwise
  /// (there's no single cross-sport rating to sort the "All" view by).
  int _rankValue(Map<String, dynamic> athlete) {
    if (_filter == 'All') return _toInt(athlete['points']);
    final ratings = athlete['ratings'] as Map?;
    return (ratings?[RatingService.sportKey(_filter)] as num?)?.toInt() ??
        kStartingRating;
  }

  String get _unitLabel => _filter == 'All' ? 'pts' : 'Rating';

  String _displayName(Map<String, dynamic> athlete) {
    final fullName = (athlete['fullName'] as String? ?? '').trim();
    if (fullName.isNotEmpty) return fullName;
    final first = (athlete['firstName'] as String? ?? '').trim();
    final last = (athlete['lastName'] as String? ?? '').trim();
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return 'Unnamed Athlete';
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