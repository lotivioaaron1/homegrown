// lib/screens/scout/scout_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../services/team_service.dart';
import '../../widgets/athlete_profile_sheet.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const List<Map<String, String>> _kSports = [
  {'label': 'All Sports', 'emoji': '🏅'},
  {'label': 'Basketball',  'emoji': '🏀'},
  {'label': 'Volleyball',  'emoji': '🏐'},
  {'label': 'Badminton',   'emoji': '🏸'},
];

// ─────────────────────────────────────────────
// ScoutScreen
// ─────────────────────────────────────────────

class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key});
  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  final _searchCtrl      = TextEditingController();
  String  _selectedSport = 'All Sports';
  bool    _openOnly      = false;
  String  _searchQuery   = '';
  Map<String, dynamic>? _coachProfile;

  @override
  void initState() {
    super.initState();
    // Fetched once and cached — the coach's own name/team don't change
    // mid-session, so there's no need to re-read on every profile-sheet open.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) setState(() => _coachProfile = doc.data());
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildSearchBar(),
        _buildSportTabs(),
        _buildRecruitmentToggle(),
        Expanded(child: _buildAthleteList()),
      ])),
    );
  }

  // ── Top bar ───────────────────────────────

  Widget _buildTopBar() => Padding(
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
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Scout Athletes', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
        Text('Find talent in Legazpi City',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ]),
    ]),
  );

  // ── Search bar ────────────────────────────

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: TextField(
      controller:  _searchCtrl,
      onChanged:   (v) => setState(() => _searchQuery = v.trim()),
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText:   'Search athlete by name...',
        hintStyle:  TextStyle(color: AppTheme.muted, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded,
            color: AppTheme.muted, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close_rounded,
                    color: AppTheme.muted, size: 18))
            : null,
        filled:    true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: AppTheme.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: AppTheme.accent, width: 1.5)),
      ),
    ),
  );

  // ── Sport tabs ────────────────────────────

  Widget _buildSportTabs() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _kSports.map((sport) {
          final label = sport['label']!;
          final emoji = sport['emoji']!;
          final sel   = _selectedSport == label;
          return GestureDetector(
            onTap: () => setState(() => _selectedSport = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppTheme.accent : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(
                  color: sel
                      ? AppTheme.buttonFg : AppTheme.muted,
                  fontSize:   13,
                  fontWeight: sel
                      ? FontWeight.w800 : FontWeight.w500)),
              ]),
            ),
          );
        }).toList(),
      ),
    ),
  );

  // ── Recruitment toggle ────────────────────

  Widget _buildRecruitmentToggle() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: GestureDetector(
      onTap: () => setState(() => _openOnly = !_openOnly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _openOnly
              ? const Color(0xFF0D2E20) : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _openOnly ? AppTheme.success : AppTheme.border,
            width: _openOnly ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.verified_rounded,
            color: _openOnly ? AppTheme.success : AppTheme.muted,
            size: 18),
          const SizedBox(width: 10),
          Text('Open to Recruitment Only',
            style: TextStyle(
              color: _openOnly ? AppTheme.success : AppTheme.sub,
              fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Switch(
            value:             _openOnly,
            onChanged:         (v) => setState(() => _openOnly = v),
            activeColor:       AppTheme.success,
            inactiveThumbColor: AppTheme.muted,
            inactiveTrackColor: AppTheme.border,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    ),
  );

  // ── Athlete list ──────────────────────────

  Widget _buildAthleteList() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'athlete');

    if (_selectedSport != 'All Sports') {
      query = query.where('primarySports',
          arrayContains: _selectedSport);
    }
    if (_openOnly) {
      query = query.where('openToRecruitment', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2.5));
        }
        if (snapshot.hasError) {
          return _buildEmpty(
            icon:     Icons.error_outline,
            title:    'Something went wrong',
            subtitle: snapshot.error.toString());
        }

        var athletes = (snapshot.data?.docs ?? [])
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          athletes = athletes.where((a) {
            final name =
                '${a['firstName']} ${a['lastName']}'.toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        // Sort by points descending
        athletes.sort((a, b) =>
            _toInt(b['points']).compareTo(_toInt(a['points'])));

        if (athletes.isEmpty) {
          return _buildEmpty(
            icon:  Icons.search_off_rounded,
            title: _searchQuery.isNotEmpty
                ? 'No athletes found'
                : _openOnly
                    ? 'No athletes open to recruitment'
                    : 'No athletes yet',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try a different name or filter'
                : _selectedSport != 'All Sports'
                    ? 'No $_selectedSport athletes registered'
                    : 'Athletes will appear here once registered');
        }

        return Column(children: [
          // Count header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Text(
                '${athletes.length} athlete${athletes.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color:      AppTheme.textPrimary,
                  fontSize:   12,
                  fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectedSport != 'All Sports')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent)),
                  child: Text(_selectedSport, style: TextStyle(
                    color:      AppTheme.accentText,
                    fontSize:   10,
                    fontWeight: FontWeight.w700))),
            ]),
          ),

          // Athlete cards
          Expanded(
            child: RefreshIndicator(
              color:           AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: athletes.length,
                itemBuilder: (_, i) => _AthleteCard(
                  athlete: athletes[i],
                  rank:    i + 1,
                  onTap:   () => _showProfile(athletes[i]),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // ── Profile bottom sheet ──────────────────

  void _showProfile(Map<String, dynamic> a) {
    final athleteUid = a['uid'] as String? ?? '';
    showAthleteProfileSheet(
      context,
      athleteId: athleteUid,
      trailingActionBuilder: (context, athlete) {
        final firstName = athlete['firstName'] as String? ?? '';
        final lastName = athlete['lastName'] as String? ?? '';
        return _buildInviteButton(athleteUid, '$firstName $lastName',
            athlete['photoUrl'] as String?);
      },
    );
  }

  // ── Invite to Team button ─────────────────

  Widget _buildInviteButton(
      String athleteUid, String athleteName, String? athletePhotoUrl) {
    final coachUid = FirebaseAuth.instance.currentUser?.uid;
    if (coachUid == null || athleteUid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(coachUid),
      builder: (context, rosterSnapshot) {
        final isFull =
            (rosterSnapshot.data?.docs.length ?? 0) >= TeamService.maxPlayers;

        return StreamBuilder<DocumentSnapshot>(
          stream: TeamService.streamMembershipStatus(coachUid, athleteUid),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final status = data?['status'] as String?;

            if (status == 'accepted') {
              return _inviteButton(
                label: 'Already on Your Team',
                color: AppTheme.success,
                onPressed: null,
              );
            }
            if (status == 'pending') {
              return _inviteButton(
                label: 'Invite Pending',
                color: AppTheme.muted,
                onPressed: null,
              );
            }
            if (isFull) {
              return _inviteButton(
                label: 'Team Full',
                color: AppTheme.muted,
                onPressed: null,
              );
            }
            return _inviteButton(
              label: 'Invite to Team',
              color: AppTheme.accent,
              onPressed: () async {
                final coachName = _coachProfile?['fullName'] as String? ?? '';
                final teamName =
                    _coachProfile?['teamOrganization'] as String? ?? 'your team';
                try {
                  await TeamService.sendInvite(
                    coachId: coachUid,
                    coachName: coachName,
                    teamName: teamName,
                    athleteId: athleteUid,
                    athleteName: athleteName,
                    athletePhotoUrl: athletePhotoUrl,
                  );
                  Get.snackbar('Invite Sent', 'Invite sent to $athleteName',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.card,
                      colorText: AppTheme.textPrimary,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                      duration: const Duration(seconds: 2));
                } on TeamFullException {
                  Get.snackbar('Team Full',
                      'Your roster is already at its max of '
                          '${TeamService.maxPlayers} players.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.card,
                      colorText: AppTheme.textPrimary,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                      duration: const Duration(seconds: 2));
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _inviteButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: AppTheme.buttonFg,
              disabledBackgroundColor: color.withValues(alpha: 0.25),
              disabledForegroundColor: color),
          child: Text(label, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );

  // ── Empty state ───────────────────────────

  Widget _buildEmpty({
    required IconData icon,
    required String   title,
    required String   subtitle,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent)),
              child: Icon(icon, color: AppTheme.accent, size: 32)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
              style: TextStyle(
                color:      AppTheme.textPrimary,
                fontSize:   16,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.sub, fontSize: 13, height: 1.5)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
// Athlete Card Widget
// ─────────────────────────────────────────────

class _AthleteCard extends StatelessWidget {
  final Map<String, dynamic> athlete;
  final int                  rank;
  final VoidCallback          onTap;

  const _AthleteCard({
    required this.athlete,
    required this.rank,
    required this.onTap,
  });

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }

  Color get _rankColor {
    switch (rank) {
      case 1:  return const Color(0xFFFFB800);
      case 2:  return const Color(0xFF8888AA);
      case 3:  return const Color(0xFFCC9500);
      default: return AppTheme.muted;
    }
  }

  String get _rankEmoji {
    switch (rank) {
      case 1:  return '🥇';
      case 2:  return '🥈';
      case 3:  return '🥉';
      default: return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = athlete['firstName'] as String? ?? '';
    final lastName  = athlete['lastName']  as String? ?? '';
    final position  = athlete['position']  as String? ?? '—';
    final barangay  = athlete['barangay']  as String? ?? '—';
    final years     = athlete['yearsOfPlaying'] as String? ?? '';
    final sports    = (athlete['primarySports'] as List?)
        ?.map((e) => e.toString()).toList() ?? [];
    final isOpen    = athlete['openToRecruitment'] as bool? ?? false;
    final pts       = _toInt(athlete['points']);
    final photoUrl  = athlete['photoUrl'] as String?;
    final initials  =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rank <= 3
                ? _rankColor.withValues(alpha: 0.5)
                : AppTheme.border,
            width: rank <= 3 ? 1.5 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              // Rank badge
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? _rankColor.withValues(alpha: 0.15)
                      : AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(8),
                  border: rank <= 3
                      ? Border.all(color: _rankColor) : null),
                child: Center(child: rank <= 3
                    ? Text(_rankEmoji,
                        style: const TextStyle(fontSize: 14))
                    : Text('#$rank', style: TextStyle(
                        color: AppTheme.muted, fontSize: 11,
                        fontWeight: FontWeight.w800)))),
              const SizedBox(width: 10),

              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: rank <= 3
                        ? [_rankColor,
                           _rankColor.withValues(alpha: 0.7)]
                        : [AppTheme.cardNested,
                           AppTheme.cardNested]),
                  borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover,
                          width: 42, height: 42,
                          errorBuilder: (_, __, ___) => Center(
                              child: Text(initials, style: TextStyle(
                                  color: rank <= 3
                                      ? AppTheme.buttonFg : AppTheme.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800))))
                      : Center(child: Text(initials,
                          style: TextStyle(
                              color: rank <= 3
                                  ? AppTheme.buttonFg : AppTheme.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800))),
                )),
              const SizedBox(width: 10),

              // Name + position
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('$firstName $lastName', style: TextStyle(
                  color:      AppTheme.textPrimary,
                  fontSize:   14,
                  fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$position · $barangay', style: TextStyle(
                  color:    AppTheme.sub,
                  fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              ])),

              const SizedBox(width: 8),

              // Points
              Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                Text('$pts', style: TextStyle(
                  color:      AppTheme.accent,
                  fontSize:   20,
                  fontWeight: FontWeight.w900,
                  height:     1)),
                Text('pts', style: TextStyle(
                    color: AppTheme.muted, fontSize: 10)),
              ]),
            ]),

            const SizedBox(height: 10),

            // Bottom row — sport tags + recruitment
            Row(children: [
              // Sport chips
              Expanded(child: Wrap(spacing: 5, children: [
                ...sports.take(2).map((s) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accent)),
                  child: Text(s, style: TextStyle(
                    color:      AppTheme.accentText,
                    fontSize:   10,
                    fontWeight: FontWeight.w600)))),
                if (years.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.cardNested,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border)),
                    child: Text(years, style: TextStyle(
                      color:    AppTheme.muted,
                      fontSize: 10))),
              ])),

              const SizedBox(width: 8),

              // Open/Closed badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFF0D2E20)
                      : AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen
                        ? AppTheme.success : AppTheme.border)),
                child: Row(mainAxisSize: MainAxisSize.min,
                  children: [
                  Icon(isOpen
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                    color: isOpen
                        ? AppTheme.success : AppTheme.muted,
                    size: 12),
                  const SizedBox(width: 4),
                  Text(isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: isOpen
                          ? AppTheme.success : AppTheme.muted,
                      fontSize:   10,
                      fontWeight: FontWeight.w700)),
                ])),
            ]),
          ]),
        ),
      ),
    );
  }
}