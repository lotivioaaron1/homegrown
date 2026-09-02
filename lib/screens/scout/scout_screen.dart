// lib/screens/scout/scout_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../services/team_service.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../utils/error_messages.dart';
import '../../utils/stat_scoring.dart';
import '../../utils/sports.dart';
import '../profile/edit_profile_screen.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const String _kAllSports = 'All Sports';

const Map<String, String> _kSportEmoji = {
  _kAllSports:  '🏅',
  'Basketball': '🏀',
  'Volleyball': '🏐',
  'Badminton':  '🏸',
};

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
  String  _selectedSport = _kAllSports;
  bool    _openOnly      = false;
  String  _searchQuery   = '';

  // The signed-in coach's own doc. The athlete query is built from the
  // sports they coach, so the list can't be shown until this has loaded.
  Map<String, dynamic>? _coachProfile;
  bool   _loadingProfile = true;
  Object? _profileError;

  // ── Skill sort ────────────────────────────
  // `null` keeps the default "most total points first" ordering. A skill is
  // only meaningful inside one sport, so the selection is dropped whenever
  // the sport tab changes.
  String? _selectedSkill;

  // Per-athlete averages for `_skillDataSport`, fetched once per sport so
  // that flipping between that sport's skills costs nothing. The sport is
  // tracked alongside the data so a stale map can never rank a list.
  Map<String, AthleteSkillAverages> _skillData = {};
  String? _skillDataSport;

  // The sport whose fetch is in flight, so a second tap on the same sport
  // doesn't duplicate the query and a slow earlier fetch can't overwrite a
  // newer sport's data when the coach taps through the tabs quickly.
  String? _loadingSport;

  @override
  void initState() {
    super.initState();
    _loadCoachProfile();
  }

  /// Fetched once and cached — the coach's own name, team and coached sports
  /// don't change mid-session, so there's no need to re-read on every
  /// profile-sheet open. A failure here has to surface: without the coached
  /// sports there is no athlete query to run, so silently swallowing it
  /// would leave the screen spinning forever.
  Future<void> _loadCoachProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _coachProfile   = doc.data();
        _loadingProfile = false;
        // A coach of a single sport has nothing to switch between, so open
        // straight on that sport rather than a one-item "All Sports".
        final sports = sportsOf(_coachProfile);
        if (sports.length == 1) _selectedSport = sports.first;
      });
      if (_selectedSport != _kAllSports) _loadSkillAverages(_selectedSport);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError   = e;
        _loadingProfile = false;
      });
    }
  }

  /// The sports this coach coaches, in the order they chose them at
  /// registration. Empty for a profile that predates the field or was
  /// hand-edited — handled explicitly rather than silently matching nobody.
  List<String> get _coachSports => sportsOf(_coachProfile);

  /// The sport tabs to offer. "All Sports" means "all of the sports I
  /// coach", so it only earns a tab when there is more than one.
  List<String> get _sportTabs => _coachSports.length > 1
      ? [_kAllSports, ..._coachSports]
      : _coachSports;

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

  // ── Skill sort ────────────────────────────

  /// The skill currently ranking the list, or `null` for the default points
  /// ordering. Also returns `null` while the chosen sport's averages are
  /// still loading or failed to load, so the list falls back to points
  /// rather than showing a ranking built on missing data.
  ScoutSkill? get _activeSkill {
    if (_selectedSkill == null || _skillDataSport != _selectedSport) {
      return null;
    }
    return kScoutSkills[_selectedSport]
        ?.where((s) => s.label == _selectedSkill)
        .firstOrNull;
  }

  /// [athlete]'s per-game average for [skill], or 0 when they have no
  /// recorded games for the sport.
  double _skillValue(Map<String, dynamic> athlete, ScoutSkill skill) =>
      _skillData[athlete['uid']]?.averages[skill.statKey] ?? 0;

  void _selectSport(String label) {
    if (label == _selectedSport) return;
    setState(() {
      _selectedSport = label;
      // A basketball skill means nothing once the coach switches to
      // volleyball, so the sort resets to points along with the sport.
      _selectedSkill = null;
    });
    if (label != _kAllSports) _loadSkillAverages(label);
  }

  /// Fetches every stat line recorded for [sport] and reduces it to one
  /// scouting line per athlete. `stats` is readable by any signed-in user
  /// (see firestore.rules), and filtering on a single field needs no
  /// composite index.
  Future<void> _loadSkillAverages(String sport) async {
    if (_skillDataSport == sport || _loadingSport == sport) return;
    setState(() => _loadingSport = sport);

    Map<String, AthleteSkillAverages>? loaded;
    Object? failure;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stats')
          .where('sport', isEqualTo: sport)
          .get();
      loaded = skillAveragesByAthlete(sport, snap.docs.map((d) => d.data()));
    } catch (e) {
      failure = e;
    }

    if (!mounted) return;

    // The coach may have moved to another sport while this was in flight;
    // that sport's own fetch owns the result now, so this one is dropped.
    final stale = sport != _selectedSport;
    setState(() {
      if (_loadingSport == sport) _loadingSport = null;
      if (stale) return;
      if (loaded != null) {
        _skillData      = loaded;
        _skillDataSport = sport;
      } else {
        // Losing the whole roster because an aggregate query failed would
        // be worse than an unranked list, so fall back to the points sort
        // and leave the athletes on screen.
        _selectedSkill = null;
      }
    });

    if (!stale && failure != null) {
      Get.snackbar('Could not load skill stats', friendlyError(failure),
          snackPosition:   SnackPosition.BOTTOM,
          backgroundColor: AppTheme.card,
          colorText:       AppTheme.textPrimary,
          margin:          const EdgeInsets.all(16),
          borderRadius:    12,
          duration:        const Duration(seconds: 3));
    }
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
        _buildSkillChips(),
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
  // Only the sports this coach coaches. A basketball coach has no business
  // scouting — or inviting — a badminton player, so those athletes are never
  // reachable from here rather than being shown and then refused.

  Widget _buildSportTabs() {
    final tabs = _sportTabs;
    // Nothing to switch between for a single-sport coach; the header already
    // names the sport via the count row's chip.
    if (tabs.length < 2) return const SizedBox.shrink();

    return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((label) {
          final emoji = _kSportEmoji[label] ?? '🏅';
          final sel   = _selectedSport == label;
          return GestureDetector(
            onTap: () => _selectSport(label),
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
  }

  // ── Skill chips ───────────────────────────
  // Ranks the list by one stat category — the thing a coach is actually
  // shopping for ("who rebounds?") rather than the blended points total.
  // Only shown once a sport is picked, since a skill has no meaning across
  // sports: there is no rebounding in badminton.

  Widget _buildSkillChips() {
    final skills = kScoutSkills[_selectedSport];
    if (skills == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 32,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // Marks the row as a sort, distinguishing it from the sport
            // filter tabs directly above it.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _loadingSport == _selectedSport
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: AppTheme.muted, strokeWidth: 2))
                  : Icon(Icons.swap_vert_rounded,
                      color: AppTheme.muted, size: 18),
            ),
            _skillChip('Top Points', _selectedSkill == null,
                () => setState(() => _selectedSkill = null)),
            ...skills.map((s) => _skillChip(
                  s.label,
                  _selectedSkill == s.label,
                  () {
                    setState(() => _selectedSkill = s.label);
                    _loadSkillAverages(_selectedSport);
                  },
                )),
          ]),
        ),
      ),
    );
  }

  Widget _skillChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
              width: selected ? 2 : 1.5)),
          child: Text(label, style: TextStyle(
            color:      selected ? AppTheme.accentText : AppTheme.muted,
            fontSize:   12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
              ? AppTheme.successSurface : AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _openOnly ? AppTheme.successText : AppTheme.border,
            width: _openOnly ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.verified_rounded,
            color: _openOnly ? AppTheme.successText : AppTheme.muted,
            size: 18),
          const SizedBox(width: 10),
          Text('Open to Recruitment Only',
            style: TextStyle(
              color: _openOnly ? AppTheme.successText : AppTheme.sub,
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
    // The query is built from the coach's own sports, so it can't be run
    // until their profile has loaded.
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator(
          color: AppTheme.accent, strokeWidth: 2.5));
    }
    if (_profileError != null) {
      return _buildEmpty(
        icon:     Icons.error_outline,
        title:    'Could not load your profile',
        subtitle: friendlyError(_profileError));
    }

    final coachSports = _coachSports;
    if (coachSports.isEmpty) {
      // A profile predating the coached-sports field, or one hand-edited in
      // the console. Showing an empty athlete list would read as "there are
      // no athletes"; say what's actually wrong and where to fix it.
      return _buildEmpty(
        icon:        Icons.sports_outlined,
        title:       'Choose the sports you coach',
        subtitle:    'Scouting shows athletes from the sports on your '
                     'profile. Add at least one to start scouting.',
        actionLabel: 'Edit Profile',
        onAction:    () async {
          await Get.to(() => const EditProfileScreen());
          // Re-read the profile on the way back, or the sports they just
          // chose wouldn't take effect until the screen was reopened.
          if (!mounted) return;
          setState(() => _loadingProfile = true);
          await _loadCoachProfile();
        });
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'athlete');

    // "All Sports" means all of the sports this coach coaches — never every
    // sport in the app.
    query = _selectedSport == _kAllSports
        ? query.where('primarySports', arrayContainsAny: coachSports)
        : query.where('primarySports', arrayContains: _selectedSport);

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
            subtitle: friendlyError(snapshot.error));
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

        // Rank by the selected skill, or by total points by default. When a
        // skill is active the athletes who have never had stats recorded
        // can't be ranked by it, so they're held back and appended under
        // their own header rather than being dropped from the list.
        final skill = _activeSkill;
        final rows  = <_ScoutRow>[];
        var rankedCount = athletes.length;

        if (skill == null) {
          athletes.sort((a, b) =>
              _toInt(b['points']).compareTo(_toInt(a['points'])));
          for (var i = 0; i < athletes.length; i++) {
            rows.add(_ScoutRow.athlete(athletes[i], rank: i + 1));
          }
        } else {
          final ranked   = <Map<String, dynamic>>[];
          final unranked = <Map<String, dynamic>>[];
          for (final a in athletes) {
            (_skillData.containsKey(a['uid']) ? ranked : unranked).add(a);
          }
          ranked.sort((a, b) =>
              _skillValue(b, skill).compareTo(_skillValue(a, skill)));
          rankedCount = ranked.length;

          for (var i = 0; i < ranked.length; i++) {
            rows.add(_ScoutRow.athlete(ranked[i], rank: i + 1));
          }
          if (unranked.isNotEmpty) {
            rows.add(_ScoutRow.header(unranked.length));
            // No rank number for these — a "#14" beside someone the sort
            // couldn't place would be a lie.
            rows.addAll(unranked.map(_ScoutRow.athlete));
          }
        }

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
                : _selectedSport != _kAllSports
                    ? 'No $_selectedSport athletes registered'
                    : 'Athletes will appear here once registered');
        }

        return Column(children: [
          // Count header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Text(
                skill != null
                    ? '$rankedCount ranked by ${skill.label}'
                    : '${athletes.length} athlete${athletes.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color:      AppTheme.textPrimary,
                  fontSize:   12,
                  fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectedSport != _kAllSports)
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
                // Drop the cached averages so a pull-to-refresh picks up
                // stats recorded since the sport was first opened.
                final sport = _skillDataSport;
                setState(() => _skillDataSport = null);
                if (sport != null) await _loadSkillAverages(sport);
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  if (row.isHeader) {
                    return _buildUnrankedHeader(row.unrankedCount!, skill!);
                  }

                  final athlete = row.athleteData!;
                  // A ranked row shows the skill it was ranked by; an
                  // unranked one falls back to the points figure.
                  final ranking = row.rank == null ? null : skill;
                  final line    = _skillData[athlete['uid']];

                  return _AthleteCard(
                    athlete:    athlete,
                    rank:       row.rank,
                    skill:      ranking,
                    skillValue: ranking == null
                        ? null
                        : line?.averages[ranking.statKey],
                    games:      ranking == null ? null : line?.games,
                    onTap:      () => _showProfile(athlete),
                  );
                },
              ),
            ),
          ),
        ]);
      },
    );
  }

  // ── Unranked group header ─────────────────
  // Athletes with no recorded games can't be placed in a skill ranking, but
  // hiding them would make the roster look empty while the app is young —
  // and they're exactly the unproven players a coach might want to look at.

  Widget _buildUnrankedHeader(int count, ScoutSkill skill) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Row(children: [
      Expanded(child: Divider(color: AppTheme.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('No ${skill.label.toLowerCase()} stats yet · $count',
          style: TextStyle(
            color:      AppTheme.muted,
            fontSize:   11,
            fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: AppTheme.border)),
    ]),
  );

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
            athlete['photoUrl'] as String?, sportsOf(athlete));
      },
    );
  }

  // ── Invite to Team button ─────────────────

  Widget _buildInviteButton(String athleteUid, String athleteName,
      String? athletePhotoUrl, List<String> athleteSports) {
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
                    coachSports: _coachSports,
                    athleteSports: athleteSports,
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
                } on SportMismatchException {
                  // Scout shouldn't be able to surface this athlete at all,
                  // so reaching here means the profile changed sports since
                  // the list loaded.
                  Get.snackbar('Different Sport',
                      '$athleteName does not play a sport you coach.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.card,
                      colorText: AppTheme.textPrimary,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                      duration: const Duration(seconds: 3));
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
    String?           actionLabel,
    VoidCallback?     onAction,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180, height: 46,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel))),
            ],
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
// Scout list row
// ─────────────────────────────────────────────

/// One row of the scout list: an athlete card, or the divider that separates
/// the athletes a skill sort could rank from those with no games recorded.
///
/// The rows are built up front so the list builder can index them directly —
/// the alternative, offsetting every index past the divider, is where
/// off-by-one bugs live.
class _ScoutRow {
  final Map<String, dynamic>? athleteData;

  /// The athlete's place in the ranking, or `null` if the sort couldn't
  /// place them.
  final int? rank;

  /// How many athletes follow the divider. Non-null only on a divider row.
  final int? unrankedCount;

  const _ScoutRow.athlete(this.athleteData, {this.rank}) : unrankedCount = null;

  const _ScoutRow.header(this.unrankedCount)
      : athleteData = null,
        rank        = null;

  bool get isHeader => unrankedCount != null;
}

// ─────────────────────────────────────────────
// Athlete Card Widget
// ─────────────────────────────────────────────

class _AthleteCard extends StatelessWidget {
  final Map<String, dynamic> athlete;

  /// `null` for an athlete the active skill sort couldn't place.
  final int?        rank;
  final VoidCallback onTap;

  /// When a skill sort is active, the skill being ranked by along with this
  /// athlete's per-game average and the number of games behind it. The card
  /// shows those in place of the total-points figure, so the coach can see
  /// the number the list is ordered by.
  final ScoutSkill? skill;
  final double?     skillValue;
  final int?        games;

  const _AthleteCard({
    required this.athlete,
    required this.rank,
    required this.onTap,
    this.skill,
    this.skillValue,
    this.games,
  });

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }

  bool get _isMedal => rank != null && rank! <= 3;

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
      default: return rank == null ? '—' : '#$rank';
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
            color: _isMedal
                ? _rankColor.withValues(alpha: 0.5)
                : AppTheme.border,
            width: _isMedal ? 1.5 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              // Rank badge
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _isMedal
                      ? _rankColor.withValues(alpha: 0.15)
                      : AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(8),
                  border: _isMedal
                      ? Border.all(color: _rankColor) : null),
                child: Center(child: _isMedal
                    ? Text(_rankEmoji,
                        style: const TextStyle(fontSize: 14))
                    // A dash, not a number, for an athlete the sort
                    // couldn't place.
                    : Text(rank == null ? '—' : '#$rank',
                        style: TextStyle(
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
                    colors: _isMedal
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
                                  color: _isMedal
                                      ? AppTheme.buttonFg : AppTheme.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800))))
                      : Center(child: Text(initials,
                          style: TextStyle(
                              color: _isMedal
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

              // Headline figure — the skill being ranked by when a skill
              // sort is on, otherwise the lifetime points total. The game
              // count sits directly under the average, because "9.5
              // rebounds" reads very differently over 2 games than over 20.
              Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: skill != null && skillValue != null
                  ? [
                      Text(formatStatAverage(skillValue!),
                        style: const TextStyle(
                          color:      AppTheme.accent,
                          fontSize:   20,
                          fontWeight: FontWeight.w900,
                          height:     1)),
                      Text(skill!.unit, style: TextStyle(
                          color: AppTheme.muted, fontSize: 10)),
                      if (games != null)
                        Text('$games game${games == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: AppTheme.muted, fontSize: 9)),
                    ]
                  : [
                      Text('$pts', style: const TextStyle(
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
                      ? AppTheme.successSurface
                      : AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen
                        ? AppTheme.successText : AppTheme.border)),
                child: Row(mainAxisSize: MainAxisSize.min,
                  children: [
                  Icon(isOpen
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                    color: isOpen
                        ? AppTheme.successText : AppTheme.muted,
                    size: 12),
                  const SizedBox(width: 4),
                  Text(isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: isOpen
                          ? AppTheme.successText : AppTheme.muted,
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