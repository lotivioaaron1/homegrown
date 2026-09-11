// lib/screens/leaderboard/leaderboard_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../utils/firestore_helpers.dart';
import '../../utils/leaderboard_ranks.dart';
import '../../utils/sports.dart';
import '../../widgets/points_explainer_sheet.dart';
import '../../widgets/skeleton.dart';

const List<String> _kFilters = ['All', 'Basketball', 'Volleyball', 'Badminton'];

/// Glyph per sport, shared by the filter chips and the row subtitles so the
/// two read as the same vocabulary.
const Map<String, String> _kSportEmoji = {
  'Basketball': '🏀',
  'Volleyball': '🏐',
  'Badminton': '🏸',
};

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

  // Name search, filtered client-side over the already-streamed result set —
  // Firestore has no substring operator, and the board is capped at
  // _kMaxRankedAthletes anyway, so this costs no extra reads.
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  String? _streamedFilter;
  Stream<QuerySnapshot>? _athletesStream;

  /// The viewer's own document, held for exactly the reason [_athleteStream]
  /// is: it used to be built inside a `builder`, so every rebuild — every
  /// search keystroke, every filter tap, every pull-to-refresh — was a new
  /// stream identity that tore down the subscription and re-read the doc.
  Stream<DocumentSnapshot>? _viewerStream;

  Stream<DocumentSnapshot> _viewerDoc() => _viewerStream ??=
      FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
          _buildSearchBar(),
          _buildFilterRow(),
          _buildRankingBasis(),
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

  // Deliberately identical in shape and styling to Scout's search bar
  // (scout_screen.dart): a coach moves between the two screens constantly and
  // they should not feel like different apps.
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search athlete by name...',
            hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
            prefixIcon:
                Icon(LucideIcons.search, color: AppTheme.muted, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(LucideIcons.x, color: AppTheme.muted, size: 18))
                : null,
            filled: true,
            fillColor: AppTheme.card,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5)),
          ),
        ),
      );

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
                f == 'All' ? 'All Sports' : '${_kSportEmoji[f] ?? ''} $f'.trim(),
                style: TextStyle(
                  color: sel ? AppTheme.accentText : AppTheme.muted,
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Says what the numbers are. The All view ranks by Homegrown points and a
  /// sport filter by match rating, and the switch between the two used to
  /// happen without a word — a new athlete could jump from #12 to #1 just by
  /// tapping a chip.
  Widget _buildRankingBasis() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPointsExplainerSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(children: [
            Icon(LucideIcons.info, color: AppTheme.muted, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _filter == 'All'
                      ? 'Ranked by total Homegrown points'
                      : 'Ranked by $_filter match rating',
                  style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            Text('How it works',
                style: TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  /// Shown in place of the podium when nobody on the board has earned a rank.
  Widget _buildNoRanksYet() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent)),
            child: const Icon(LucideIcons.crown,
                color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _filter == 'All'
                          ? 'No recorded games yet'
                          : 'No rated $_filter matches yet',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      'Rankings start after the first match an organizer '
                      'records. Everyone is unranked until then.',
                      style: TextStyle(
                          color: AppTheme.sub, fontSize: 12, height: 1.4)),
                ]),
          ),
        ]),
      );

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _athleteStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LeaderboardSkeleton();
        }
        if (snapshot.hasError) {
          return _buildEmpty(
            icon: LucideIcons.alertCircle,
            title: 'Something went wrong',
            subtitle: friendlyError(snapshot.error));
        }

        final docs = snapshot.data?.docs ?? [];

        // The "All" filter constrains on role alone, so — unlike Scout, whose
        // primarySports clause happens to exclude them — the deletion
        // tombstones reach this list and would rank as nameless rows on 0
        // points. See isListableProfile, which is a safety net only: an
        // orphaned profile that kept its name still needs a data cleanup.
        final athletes = docs
            .map((d) => d.data() as Map<String, dynamic>)
            .where(isListableProfile)
            .toList()
          ..sort(_compareAthletes);

        // Checked after that filter rather than on `docs`: a board holding
        // nothing but deleted profiles is empty, and saying so beats
        // rendering a header above no rows.
        if (athletes.isEmpty) {
          return _buildEmpty(
            icon: LucideIcons.trophy,
            title: 'No athletes yet',
            // Addressed to whoever is looking — usually an athlete — rather
            // than to an admin who can "register athletes".
            subtitle: _filter == 'All'
                ? 'Athletes appear here once they sign up'
                : 'No $_filter athletes found');
        }

        final searching = _searchQuery.isNotEmpty;

        // Ranks are fixed here, against the full sorted board, before any
        // search narrows it. An athlete found by name must still show the
        // position they actually hold — renumbering the matches would tell
        // someone they are #2 when they are #37.
        //
        // Equal scores share a rank and consume the numbers behind them
        // (1, 2, 2, 4), which lines the board up with RankingService.cityRank.
        //
        // Athletes with nothing recorded — no points in the All view, no
        // rating in a filtered sport — get no rank at all (null, shown "—").
        // They used to be numbered too, and because they all sit on the same
        // value they all tied for first: with no stats recorded yet, the
        // whole city was "#1". See leaderboard_ranks.dart.
        final ranks = assignRanks(athletes,
            valueOf: _rankValue, isUnranked: _isUnranked);
        final ranked = <(int?, Map<String, dynamic>)>[
          for (var i = 0; i < athletes.length; i++) (ranks[i], athletes[i]),
        ];

        final matches = searching
            ? ranked.where((r) {
                final a = r.$2;
                final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}';
                return name.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList()
            : ranked;

        if (searching && matches.isEmpty) {
          return _buildEmpty(
              icon: LucideIcons.searchX,
              title: 'No athletes found',
              subtitle: 'Try a different name or sport filter');
        }

        // A podium built from search results would crown whoever happens to
        // match first, so it is dropped for the duration of a search and the
        // matches render as one flat, truly-ranked list.
        //
        // Only ranked athletes can stand on it. They sort first, so the podium
        // is the leading run of ranked entries, up to three — possibly none,
        // in which case a note explains why the board has no leaders yet.
        final podiumCount = searching
            ? 0
            : matches.takeWhile((r) => r.$1 != null).take(3).length;
        final top3 = [
          for (final r in matches.take(podiumCount)) (r.$1!, r.$2),
        ];
        final rest = matches.sublist(podiumCount);
        final nobodyRanked = !searching && ranks.every((r) => r == null);

        // Position in the sorted board, which is no longer `rank - 1` now that
        // tied athletes share a number — the banner needs the index to read the
        // right athlete, and the rank only to print it.
        final myIndex = athletes.indexWhere((a) => a['uid'] == _uid);
        final myRank = myIndex >= 0 ? ranks[myIndex] : null;

        return StreamBuilder<DocumentSnapshot>(
          stream: _viewerDoc(),
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
                  if (nobodyRanked) ...[
                    _buildNoRanksYet(),
                    const SizedBox(height: 16),
                  ],
                  if (top3.isNotEmpty) ...[
                    _buildPodium(top3),
                    const SizedBox(height: 20),
                  ],
                  // Keyed off the index rather than the rank: with ties a
                  // fourth-placed athlete can still be holding rank 1, and
                  // `myRank > 3` would then hide the banner for someone who
                  // isn't on the podium. Skipped when nobody is ranked — the
                  // note above already says it, for everyone at once.
                  if (!searching && !nobodyRanked && role == 'athlete' &&
                      myIndex >= podiumCount) ...[
                    _buildMyRankBanner(myRank, athletes[myIndex]),
                    const SizedBox(height: 16),
                  ],
                  if (rest.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        searching
                            ? '${rest.length} MATCH${rest.length == 1 ? '' : 'ES'}'
                            : role == 'coach'
                                ? 'TAP ATHLETE TO SCOUT'
                                : 'FULL RANKINGS · TAP TO VIEW',
                        style: TextStyle(color: AppTheme.muted, fontSize: 10,
                            fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                    Container(
                      // Clipped so a row's ink ripple stops at the card's
                      // rounded corners instead of squaring off the first and
                      // last rows while a finger is down.
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border)),
                      child: Column(
                        children: rest.asMap().entries.map((e) {
                          final (rank, athlete) = e.value;
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

  /// The top three entries, each carrying the rank it actually holds — which
  /// is not always its place on the podium, since tied athletes share a number
  /// and a silver bar can legitimately read "#1".
  Widget _buildPodium(List<(int, Map<String, dynamic>)> top3) {
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
          const Icon(LucideIcons.crown, color: AppTheme.accent, size: 16),
          const SizedBox(width: 6),
          Text('Top Athletes', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (second != null) _podiumItem(second.$2, second.$1, 2, 70),
            const SizedBox(width: 8),
            if (first != null) _podiumItem(first.$2, first.$1, 1, 95),
            const SizedBox(width: 8),
            if (third != null) _podiumItem(third.$2, third.$1, 3, 55),
          ],
        ),
      ]),
    );
  }

  /// [rank] is the number shown; [place] is the podium slot (1/2/3) that
  /// decides the medal colour and the sizes. They usually agree, and diverge
  /// only on a tie.
  Widget _podiumItem(
      Map<String, dynamic> athlete, int rank, int place, double barH) {
    final pts = _rankValue(athlete);
    final isMe = athlete['uid'] == _uid;
    final name = _displayName(athlete);
    final photoUrl = athlete['photoUrl'] as String?;
    final colors = {
      1: [const Color(0xFFFFB800), const Color(0xFF2E1F00)],
      2: [const Color(0xFFB8BCC8), const Color(0xFF1E1E28)],
      3: [const Color(0xFFCD7F32), const Color(0xFF2E1D0F)],
    };
    final accentColor = colors[place]![0];
    final bgColor = colors[place]![1];
    final size = place == 1 ? 52.0 : 40.0;

    final initials = Center(
        child: Text(_initials(name),
            style: TextStyle(
                color: AppTheme.buttonFg,
                fontSize: place == 1 ? 16 : 13,
                fontWeight: FontWeight.w800)));

    // The three most interesting athletes on the board used to be the three
    // nobody could open. `opaque` makes the whole column — avatar, name, bar
    // and the gaps between them — one target, since the avatar alone is a
    // 40px tap area.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAthleteProfile(athlete),
      child: Column(children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            border: isMe ? Border.all(color: AppTheme.accent, width: 2.5) : null),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    memCacheWidth: 160,
                    placeholder: (_, __) => initials,
                    errorWidget: (_, __, ___) => initials)
                : initials,
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
          width: place == 1 ? 60 : 50,
          height: barH,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            border: Border.all(color: accentColor)),
          child: Center(child: Text('#$rank', style: TextStyle(
            color: accentColor, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
      ]),
    );
  }

  /// Tappable like every other person on this board — here it opens your own
  /// profile, which is the only way to see it the way a scouting coach does.
  ///
  /// [rank] is null while the viewer has nothing recorded on this board.
  Widget _buildMyRankBanner(int? rank, Map<String, dynamic> athlete) {
    final pts = _rankValue(athlete);
    final detail = rank == null
        ? (_filter == 'All'
            ? 'Unranked · play a recorded game to get ranked'
            : 'Unranked in $_filter · no rated matches yet')
        : (_filter == 'All'
            ? '$pts points earned so far'
            : '$pts $_unitLabel rating');
    return GestureDetector(
      onTap: () => _showAthleteProfile(athlete),
      child: Container(
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
            child: Center(child: Text(rank == null ? '—' : '$rank',
              style: const TextStyle(
              color: AppTheme.buttonFg, fontSize: 14, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Rank', style: TextStyle(
                color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(
                detail,
                style: TextStyle(
                color: AppTheme.accentText, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          const Icon(LucideIcons.star, color: AppTheme.accent, size: 20),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 16),
        ]),
      ),
    );
  }

  /// [rank] is null for an athlete with nothing recorded on this board.
  Widget _buildRow({
    required int? rank,
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

    final subtitle = [
      if (position.isNotEmpty) position,
      if (barangay.isNotEmpty) barangay,
      // Only in the All view, where the board mixes sports and the row is
      // otherwise silent about which one this athlete plays. Under a sport
      // filter every row already answers that.
      if (_filter == 'All') ..._sportMarks(athlete),
    ].join(' · ');

    final initials = Center(
        child: Text(_initials(name),
            style: TextStyle(
                color: isMe ? AppTheme.buttonFg : AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800)));

    // Open to every role, not just coaches. A leaderboard that names people
    // and then refuses to say anything about them is the wrong trade, and the
    // sheet reads nothing an ordinary signed-in account can't already read —
    // sport scoping belongs on recruiting, which lives in Scout.
    return Material(
      color: isMe
          ? AppTheme.accentSurface.withValues(alpha: 0.5)
          : Colors.transparent,
      // The divider rides on the Material rather than a Container inside it,
      // so the ink splash covers the full row instead of stopping at a nested
      // box's edge.
      shape: isLast
          ? null
          : Border(bottom: BorderSide(color: AppTheme.border)),
      child: InkWell(
        onTap: () => _showAthleteProfile(athlete),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            SizedBox(width: 24, child: Text(rank == null ? '—' : '$rank',
              style: TextStyle(
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
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        memCacheWidth: 110,
                        placeholder: (_, __) => initials,
                        errorWidget: (_, __, ___) => initials)
                    : initials,
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
                  subtitle,
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
                    fontSize: 11, fontWeight: FontWeight.w700)),
              if (!isCoach && isMe)
                Text(_unitLabel, style: TextStyle(
                  color: AppTheme.muted, fontSize: 11)),
            ]),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 18),
          ]),
        ),
      ),
    );
  }

  /// Sport glyphs for a row's subtitle, in the same vocabulary as the filter
  /// chips. Returns at most one entry so it drops straight into the
  /// `·`-joined subtitle, and a sport with no glyph contributes nothing rather
  /// than a gap.
  List<String> _sportMarks(Map<String, dynamic> athlete) {
    final marks = sportsOf(athlete)
        .map((s) => _kSportEmoji[s] ?? '')
        .where((e) => e.isNotEmpty)
        .join(' ');
    return marks.isEmpty ? const [] : [marks];
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

  /// Whether [athlete] has earned a place on the current board: any points in
  /// the All view, or a recorded rating in the filtered sport. A missing
  /// rating is read as kStartingRating by [_rankValue], which is right for
  /// display but would otherwise tie every unrated athlete for first.
  bool _isUnranked(Map<String, dynamic> athlete) {
    if (_filter == 'All') return _toInt(athlete['points']) <= 0;
    final ratings = athlete['ratings'] as Map?;
    return ratings?[RatingService.sportKey(_filter)] == null;
  }

  /// Ranked athletes first, best first. Unranked ones follow in name order,
  /// so the tail of the board is stable instead of in whatever order
  /// Firestore returned it.
  int _compareAthletes(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aUnranked = _isUnranked(a);
    final bUnranked = _isUnranked(b);
    if (aUnranked != bUnranked) return aUnranked ? 1 : -1;
    if (aUnranked) {
      return _displayName(a)
          .toLowerCase()
          .compareTo(_displayName(b).toLowerCase());
    }
    return _rankValue(b).compareTo(_rankValue(a));
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