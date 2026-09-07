// lib/widgets/team_carousel.dart

import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/team_service.dart';
import '../theme/app_theme.dart';
import 'athlete_profile_sheet.dart';
import 'coach_profile_sheet.dart';
import 'skeleton.dart';

/// The home screen's "My Team" section: a swipeable deck of photo cards that
/// expands in place into the full roster.
///
/// Split out of HomeScreen, which was already past 2,300 lines. Kept in two
/// pieces so the presentation is testable without Firebase:
///
///  * [TeamCarousel] is pure — hand it a list of [TeamMemberView]s and it
///    renders, animates and expands, touching nothing else.
///  * [TeamCarouselLoader] wraps it with the one thing the cards need that a
///    membership doc cannot supply (see [TeamService.fetchMemberProfiles]).

/// Card dimensions. The deck is a fixed height so the home screen does not
/// reflow when the roster loads or a photo fails.
const double _kCardHeight = 232;
const double _kPagePadding = 8;

/// Shared by the PageView and the skeleton so the placeholder cards land
/// exactly where the real ones will — otherwise the deck slides sideways the
/// moment data arrives, which is the reflow a skeleton exists to prevent.
const double _kViewportFraction = 0.5;

/// Height of the page-indicator row (dots plus the gap above them).
const double _kIndicatorHeight = 18;

/// How far a neighbouring card shrinks, fades and sinks at one full page away.
const double _kSideScale = 0.86;
const double _kSideOpacity = 0.55;
const double _kSideDrop = 12;

/// One person as the deck draws them.
class TeamMemberView {
  final String uid;
  final String name;

  /// Second line on the card — "Head Coach", "Point Guard", "Member since…".
  final String subtitle;
  final String? photoUrl;

  /// Coaches get the gold ring, the badge, and first position in the deck.
  final bool isCoach;

  /// True for the logged-in viewer's own membership. Gets the same "YOU" pill
  /// leaderboard_screen.dart uses to mark the viewer in a list of people —
  /// this deck used to leave the viewer out of their own team entirely.
  final bool isSelf;

  const TeamMemberView({
    required this.uid,
    required this.name,
    required this.subtitle,
    this.photoUrl,
    this.isCoach = false,
    this.isSelf = false,
  });

  String get initials => name
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();
}

/// What the caller knows before profiles are hydrated: who is on the team, and
/// the name/photo copies frozen onto the membership doc to fall back on.
class TeamMemberSeed {
  final String uid;
  final String fallbackName;
  final String? fallbackPhotoUrl;
  final String fallbackSubtitle;
  final bool isCoach;
  final bool isSelf;

  const TeamMemberSeed({
    required this.uid,
    required this.fallbackName,
    this.fallbackPhotoUrl,
    this.fallbackSubtitle = '',
    this.isCoach = false,
    this.isSelf = false,
  });
}

// ─────────────────────────────────────────────
// Loader
// ─────────────────────────────────────────────

/// Hydrates [seeds] against `users/{uid}` and renders a [TeamCarousel].
///
/// Refetches only when the set of uids actually changes — a plain
/// `FutureBuilder` inside the caller's `StreamBuilder` would start a new query
/// on every rebuild. While a refetch is in flight the previously loaded
/// profiles stay on screen, so adding a teammate does not blink the whole deck
/// back to skeletons.
class TeamCarouselLoader extends StatefulWidget {
  final String title;
  final String? countLabel;
  final bool countIsWarning;
  final List<TeamMemberSeed> seeds;
  final VoidCallback? onAddPlayer;
  final Widget? footer;

  const TeamCarouselLoader({
    super.key,
    required this.title,
    required this.seeds,
    this.countLabel,
    this.countIsWarning = false,
    this.onAddPlayer,
    this.footer,
  });

  @override
  State<TeamCarouselLoader> createState() => _TeamCarouselLoaderState();
}

class _TeamCarouselLoaderState extends State<TeamCarouselLoader> {
  Map<String, Map<String, dynamic>> _profiles = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(TeamCarouselLoader old) {
    super.didUpdateWidget(old);
    final before = old.seeds.map((s) => s.uid).toSet();
    final now = widget.seeds.map((s) => s.uid).toSet();
    if (!setEquals(before, now)) _hydrate();
  }

  Future<void> _hydrate() async {
    final uids = widget.seeds.map((s) => s.uid).toList();
    if (uids.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final fetched = await TeamService.fetchMemberProfiles(uids);
      if (!mounted) return;
      // Merge rather than replace: a member whose doc is unreadable keeps
      // whatever we already had for them instead of reverting to the seed.
      setState(() {
        _profiles = {..._profiles, ...fetched};
        _loaded = true;
      });
    } catch (_) {
      // A failed hydrate is not worth an error state — the seeds already carry
      // a usable name and photo. Fall through to rendering those.
      if (mounted) setState(() => _loaded = true);
    }
  }

  TeamMemberView _view(TeamMemberSeed seed) {
    final p = _profiles[seed.uid];
    if (p == null) {
      return TeamMemberView(
        uid: seed.uid,
        name: seed.fallbackName,
        subtitle: seed.fallbackSubtitle,
        photoUrl: seed.fallbackPhotoUrl,
        isCoach: seed.isCoach,
        isSelf: seed.isSelf,
      );
    }

    // Shared with the My Team / teammate rosters so every surface agrees on
    // which field wins — this used to prefer `fullName`, which Edit Profile
    // did not maintain, so a renamed member kept their old name here.
    final identity = resolveMemberIdentity(p,
        fallbackName: seed.fallbackName,
        fallbackPhotoUrl: seed.fallbackPhotoUrl);

    final subtitle = seed.isCoach
        ? _coachSubtitle(p)
        : ((p['position'] as String? ?? '').trim().isNotEmpty
            ? (p['position'] as String).trim()
            : seed.fallbackSubtitle);

    return TeamMemberView(
      uid: seed.uid,
      name: identity.name,
      subtitle: subtitle,
      photoUrl: identity.photoUrl,
      isCoach: seed.isCoach,
      isSelf: seed.isSelf,
    );
  }

  String _coachSubtitle(Map<String, dynamic> p) {
    final level = (p['coachingLevel'] as String? ?? '').trim();
    return level.isEmpty ? 'Head Coach' : '$level Coach';
  }

  void _openProfile(TeamMemberView m) {
    if (m.uid.isEmpty) return;
    // The viewer's own row goes to their editable profile, not the read-only
    // sheet everyone else's row opens — there is nothing to do with a
    // look-but-don't-touch view of yourself.
    if (m.isSelf) {
      Get.toNamed('/profile');
    } else if (m.isCoach) {
      showCoachProfileSheet(context,
          coachId: m.uid, coach: _profiles[m.uid], fallbackName: m.name);
    } else {
      showAthleteProfileSheet(context, athleteId: m.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded && _profiles.isEmpty && widget.seeds.isNotEmpty) {
      return TeamCarouselSkeleton(title: widget.title);
    }
    return TeamCarousel(
      title: widget.title,
      countLabel: widget.countLabel,
      countIsWarning: widget.countIsWarning,
      members: widget.seeds.map(_view).toList(),
      onMemberTap: _openProfile,
      onAddPlayer: widget.onAddPlayer,
      footer: widget.footer,
    );
  }
}

// ─────────────────────────────────────────────
// Carousel
// ─────────────────────────────────────────────

/// The deck itself. Pure presentation — no Firebase, no navigation.
class TeamCarousel extends StatefulWidget {
  final String title;
  final String? countLabel;
  final bool countIsWarning;
  final List<TeamMemberView> members;
  final ValueChanged<TeamMemberView>? onMemberTap;

  /// Coaches get a trailing "add player" card; athletes pass null.
  final VoidCallback? onAddPlayer;

  /// Rendered under the deck in both states — the pending-invite line and the
  /// "view full roster" link the home screen already showed.
  final Widget? footer;

  const TeamCarousel({
    super.key,
    required this.title,
    required this.members,
    this.countLabel,
    this.countIsWarning = false,
    this.onMemberTap,
    this.onAddPlayer,
    this.footer,
  });

  @override
  State<TeamCarousel> createState() => _TeamCarouselState();
}

class _TeamCarouselState extends State<TeamCarousel> {
  final PageController _controller =
      PageController(viewportFraction: _kViewportFraction);
  int _page = 0;
  bool _expanded = false;

  /// True when the OS asks for reduced motion. Everything that moves for
  /// decoration is switched off; the layout and its states are unchanged.
  /// Mirrors how Shimmer opts out in widgets/skeleton.dart.
  bool get _motion => !MediaQuery.of(context).disableAnimations;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Cards, plus the coach's trailing "add player" tile.
  int get _pageCount => widget.members.length + (widget.onAddPlayer != null ? 1 : 0);

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_motion) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty && widget.onAddPlayer == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildSwappable(),
        if (widget.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: widget.footer,
          ),
      ],
    );
  }

  /// Crossfades the deck and the roster, resizing the section to match.
  ///
  /// Under reduced motion the wrappers are dropped rather than given a zero
  /// duration: a zero-duration [AnimatedSize] re-dirties itself inside its own
  /// `performLayout` and asserts.
  Widget _buildSwappable() {
    final child = _expanded
        ? _buildRoster(key: const ValueKey('roster'))
        : _buildDeck(key: const ValueKey('deck'));

    if (!_motion) return child;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: child,
      ),
    );
  }

  // ── Header ─────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Row(children: [
          Expanded(
            child: Text(widget.title,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
          ),
          if (widget.countLabel != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: widget.countIsWarning
                      ? AppTheme.error.withValues(alpha: 0.12)
                      : AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: widget.countIsWarning
                          ? AppTheme.error
                          : AppTheme.accent)),
              child: Text(widget.countLabel!,
                  style: TextStyle(
                      color: widget.countIsWarning
                          ? AppTheme.error
                          : AppTheme.accentText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration:
                _motion ? const Duration(milliseconds: 260) : Duration.zero,
            curve: Curves.easeOutCubic,
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.muted, size: 22),
          ),
        ]),
      ),
    );
  }

  // ── Collapsed: the swipeable deck ──────────

  Widget _buildDeck({Key? key}) {
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: _kCardHeight,
        child: PageView.builder(
          controller: _controller,
          itemCount: _pageCount,
          padEnds: true,
          onPageChanged: (i) {
            setState(() => _page = i);
            if (_motion) HapticFeedback.selectionClick();
          },
          itemBuilder: (context, i) => _buildPage(i),
        ),
      ),
      if (_pageCount > 1) ...[
        const SizedBox(height: 12),
        _buildPageIndicator(),
      ],
    ]);
  }

  /// Wraps one card in the scale/fade/drop/parallax that the page offset
  /// drives. `offset` is signed — negative left of centre, positive right —
  /// so the photo can lean the opposite way to the swipe.
  Widget _buildPage(int index) {
    // Tapping a card opens the section, not that person — the deck shows who
    // is on the team, and expanding is how you get to any one of them. The
    // individual profiles hang off the rows in the expanded list.
    final child = index < widget.members.length
        ? _MemberCard(member: widget.members[index], onTap: _toggle)
        : _AddPlayerCard(onTap: widget.onAddPlayer!);

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
      child: child,
    );

    if (!_motion) return padded;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, inner) {
        // `page` throws before the viewport has been laid out, so fall back to
        // the resting page for the very first frame.
        final page = _controller.hasClients &&
                _controller.position.hasContentDimensions
            ? (_controller.page ?? _page.toDouble())
            : _page.toDouble();
        final offset = index - page;
        final t = offset.abs().clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(t);

        return Transform.translate(
          offset: Offset(0, lerpDouble(0, _kSideDrop, eased)!),
          child: Transform.scale(
            scale: lerpDouble(1.0, _kSideScale, eased)!,
            child: Opacity(
              opacity: lerpDouble(1.0, _kSideOpacity, eased)!,
              child: _ParallaxScope(shift: offset, child: inner!),
            ),
          ),
        );
      },
      child: padded,
    );
  }

  Widget _buildPageIndicator() {
    // Past a handful of teammates a row of dots stops being readable, and a
    // 15-player roster would run off the screen. Switch to a counter.
    if (_pageCount > 8) {
      return Text('${_page + 1} / $_pageCount',
          style: TextStyle(
              color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w700));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration:
              _motion ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
              color: active ? AppTheme.accent : AppTheme.border,
              borderRadius: BorderRadius.circular(3)),
        );
      }),
    );
  }

  // ── Expanded: the roster list ──────────────

  Widget _buildRoster({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        for (var i = 0; i < widget.members.length; i++)
          _StaggeredIn(
            index: i,
            enabled: _motion,
            child: _MemberRow(
              member: widget.members[i],
              onTap: () => widget.onMemberTap?.call(widget.members[i]),
            ),
          ),
        if (widget.onAddPlayer != null)
          _StaggeredIn(
            index: widget.members.length,
            enabled: _motion,
            child: _AddPlayerRow(onTap: widget.onAddPlayer!),
          ),
      ]),
    );
  }
}

/// Shifts a card's photo against the swipe. Read by [_MemberCard] through the
/// element tree so the parallax value does not have to be threaded through
/// every constructor between the PageView and the image.
class _ParallaxScope extends InheritedWidget {
  final double shift;
  const _ParallaxScope({required this.shift, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ParallaxScope>()?.shift ?? 0;

  @override
  bool updateShouldNotify(_ParallaxScope old) => old.shift != shift;
}

// ─────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final TeamMemberView member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Damped so the photo never slides far enough to reveal an edge.
    final parallax = (_ParallaxScope.of(context) * 0.28).clamp(-1.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: member.isCoach ? AppTheme.accent : AppTheme.border,
              width: member.isCoach ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(member.isCoach ? 18 : 19),
          child: Stack(fit: StackFit.expand, children: [
            _CardPhoto(member: member, parallax: parallax),
            // Scrim, so the name stays legible over a bright photo.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            // Same top-left slot either way — a card is never both, since a
            // coach's own deck shows their athletes, never themselves.
            if (member.isCoach)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('COACH',
                      style: TextStyle(
                          color: AppTheme.buttonFg,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ),
              )
            else if (member.isSelf)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('YOU',
                      style: TextStyle(
                          color: AppTheme.buttonFg,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  if (member.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(member.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: member.isCoach
                                ? AppTheme.accent
                                : Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The photo, or a gold initials tile when there is none — the same fallback
/// the avatar circles elsewhere in the app use.
class _CardPhoto extends StatelessWidget {
  final TeamMemberView member;
  final double parallax;

  const _CardPhoto({required this.member, required this.parallax});

  @override
  Widget build(BuildContext context) {
    final url = member.photoUrl;
    final fallback = _InitialsTile(initials: member.initials);
    if (url == null || url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: Alignment(parallax, 0),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Stand-in for a member with no photo.
///
/// The small avatar circles elsewhere in the app fill with the gold gradient,
/// but a card is forty times their area: a deck of them turns the whole
/// section into a wall of gold and leaves the gold COACH badge with nothing to
/// sit against. So the tile is a neutral surface with a gold wash, and the
/// initials carry the brand colour instead.
class _InitialsTile extends StatelessWidget {
  final String initials;
  const _InitialsTile({required this.initials});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.cardNested, AppTheme.accentSurface],
          ),
        ),
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  color: AppTheme.accent.withValues(alpha: 0.55),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ),
      );
}

class _AddPlayerCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlayerCard({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent)),
                child: Icon(Icons.add_rounded,
                    color: AppTheme.accentText, size: 22),
              ),
              const SizedBox(height: 10),
              Text('Add player',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('from Scout',
                  style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// Roster rows
// ─────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final TeamMemberView member;
  final VoidCallback onTap;

  const _MemberRow({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: member.isCoach ? AppTheme.accent : AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                  shape: BoxShape.circle),
              child: ClipOval(
                child: member.photoUrl != null && member.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: member.photoUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        placeholder: (_, __) => _RowInitials(member: member),
                        errorWidget: (_, __, ___) =>
                            _RowInitials(member: member),
                      )
                    : _RowInitials(member: member),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(member.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: member.isSelf
                                  ? AppTheme.accent
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                    // Same "YOU" pill leaderboard_screen.dart marks the viewer
                    // with, in a list of the same shape — other people's names.
                    if (member.isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('YOU',
                            style: TextStyle(
                                color: AppTheme.buttonFg,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                  if (member.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(member.subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: member.isCoach
                                ? AppTheme.accentText
                                : AppTheme.sub,
                            fontSize: 12)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
          ]),
        ),
      );
}

class _RowInitials extends StatelessWidget {
  final TeamMemberView member;
  const _RowInitials({required this.member});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(member.initials,
            style: const TextStyle(
                color: AppTheme.buttonFg,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      );
}

class _AddPlayerRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlayerRow({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent)),
              child:
                  Icon(Icons.add_rounded, color: AppTheme.accentText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Add player from Scout',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
          ]),
        ),
      );
}

/// Fades and lifts a roster row into place, offset by its position so the list
/// resolves top-to-bottom instead of appearing all at once.
class _StaggeredIn extends StatelessWidget {
  final int index;
  final bool enabled;
  final Widget child;

  const _StaggeredIn({
    required this.index,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    // Cap the ramp so a full 15-player roster does not take noticeably longer
    // to settle than a three-player one.
    final start = (index * 0.06).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, v, inner) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: inner),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// Loading
// ─────────────────────────────────────────────

/// Deck-shaped placeholder, so the section does not resize when data lands.
///
/// Public because the wait starts before the loader does: the caller's roster
/// stream has its own connecting window, and without this the section falls
/// through to its empty state and flashes "No Team Yet" at someone who has a
/// team. Pass [title] when it is already known (a coach's team name comes off
/// the user doc, which has resolved by then); leave it null and the title
/// renders as a placeholder line too.
class TeamCarouselSkeleton extends StatelessWidget {
  final String? title;
  const TeamCarouselSkeleton({super.key, this.title});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: title == null
                ? const Shimmer(child: SkeletonBox(width: 140, height: 15))
                : Text(title!,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          // Mirrors PageView's own maths: page 0 is centred, so the first
          // placeholder has to be too, with the next one peeking in from the
          // right exactly as the real deck shows it.
          LayoutBuilder(builder: (context, constraints) {
            final pageWidth = constraints.maxWidth * _kViewportFraction;
            final cardWidth = pageWidth - _kPagePadding * 2;
            final leading =
                (constraints.maxWidth - pageWidth) / 2 + _kPagePadding;
            return Shimmer(
              child: ClipRect(
                child: SizedBox(
                  height: _kCardHeight,
                  child: Stack(children: [
                    Positioned(
                      left: leading,
                      child: SkeletonBox(
                          width: cardWidth,
                          height: _kCardHeight,
                          radius: 20),
                    ),
                    Positioned(
                      left: leading + pageWidth,
                      child: SkeletonBox(
                          width: cardWidth,
                          height: _kCardHeight,
                          radius: 20),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: _kIndicatorHeight),
        ],
      );
}
