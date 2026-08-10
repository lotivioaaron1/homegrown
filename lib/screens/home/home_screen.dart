// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/auth_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _bannerDismissed = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty  ? last[0].toUpperCase()  : '';
    return '$f$l';
  }

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }

  // ── Avatar menu ───────────────────────────

  void _showAvatarMenu(BuildContext context,
      String firstName, String lastName, String role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.accent, AppTheme.accent2]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(_initials(firstName, lastName),
                style: const TextStyle(color: AppTheme.buttonFg,
                    fontSize: 16, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$firstName $lastName', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15,
                fontWeight: FontWeight.w700)),
              Text(role[0].toUpperCase() + role.substring(1),
                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 24),
          Divider(color: AppTheme.border),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () { Get.back(); AuthController.to.signOut(); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFF5C5C).withValues(alpha: 0.4))),
              child: const Row(children: [
                Icon(Icons.logout_rounded, color: Color(0xFFFF5C5C), size: 20),
                SizedBox(width: 12),
                Text('Sign Out', style: TextStyle(
                  color: Color(0xFFFF5C5C), fontSize: 15,
                  fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Navigation ────────────────────────────

  void _onNavTap(int index, String role) {
    setState(() => _navIndex = index);
    if (index == 0) return;
    if (index == 4) {
      Get.toNamed('/profile')
          ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
      return;
    }
    // Index 3 = Games/Venues for ALL roles
    if (index == 3) {
      Get.toNamed('/venues')
          ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
      return;
    }
    switch (role) {
      case 'organizer':
        if (index == 1) {
          Get.toNamed('/stats/add')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
        if (index == 2) {
          Get.toNamed('/events/create')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
        break;
      case 'coach':
        if (index == 1) {
          Get.toNamed('/scout')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
        if (index == 2) {
          Get.toNamed('/leaderboard')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
        break;
      default:
        if (index == 1) {
          Get.toNamed('/dashboard')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
        if (index == 2) {
          Get.toNamed('/leaderboard')
              ?.then((_) { if (mounted) setState(() => _navIndex = 0); });
          return;
        }
    }
    _comingSoon();
  }

  void _onFeatureTap(String feature) {
    switch (feature) {
      case 'Add Stats':      Get.toNamed('/stats/add');     return;
      case 'My Events':      Get.toNamed('/events/create'); return;
      case 'Leaderboard':    Get.toNamed('/leaderboard');   return;
      case 'Scout Athletes': Get.toNamed('/scout');         return;
      case 'My Dashboard':   Get.toNamed('/dashboard');     return;
      case 'My Profile':     Get.toNamed('/profile');       return;
      case 'Find Games':     Get.toNamed('/venues');        return;
      case 'Venues':         Get.toNamed('/venues');        return;
      default: _comingSoon(feature); return;
    }
  }

  void _comingSoon([String? feature]) {
    Get.snackbar('Coming Soon',
      feature != null ? '$feature is under construction.'
          : 'This screen is under construction.',
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: AppTheme.card,
      colorText:       AppTheme.textPrimary,
      margin:          const EdgeInsets.all(16),
      borderRadius:    12,
      duration:        const Duration(seconds: 2));
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: AppTheme.bg,
            body: Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5)));
        }
        final data      = snapshot.data?.data()
            as Map<String, dynamic>? ?? {};
        final role      = data['role']      as String? ?? 'athlete';
        final firstName = data['firstName'] as String? ?? '';
        final lastName  = data['lastName']  as String? ?? '';

        return Scaffold(
          backgroundColor: AppTheme.bg,
          floatingActionButton: role == 'organizer'
              ? FloatingActionButton(
                  onPressed: () => Get.toNamed('/events/create'),
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.buttonFg,
                  child: const Icon(Icons.add_rounded))
              : null,
          body: SafeArea(child: Column(children: [
            // ── Verification banner ───────────
            _buildVerificationBanner(),
            Expanded(child: RefreshIndicator(
              color:        AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildBody(data, role, firstName, lastName)))),
            _buildBottomNav(role),
          ])),
        );
      },
    );
  }

  Widget _buildVerificationBanner() {
    final user = FirebaseAuth.instance.currentUser;
    // Don't show for Google users or verified users or if dismissed
    if (user == null || _bannerDismissed) return const SizedBox.shrink();
    final isGoogle = user.providerData
        .any((p) => p.providerId == 'google.com');
    if (isGoogle || user.emailVerified) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.6))),
      child: Row(children: [
        const Text('✉️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verify your email', style: TextStyle(
              color: AppTheme.accentText, fontSize: 12,
              fontWeight: FontWeight.w700)),
            Text('Check your inbox and click the link we sent.',
              style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ])),
        const SizedBox(width: 8),
        // Resend button
        GestureDetector(
          onTap: () async {
            try {
              await FirebaseAuth.instance.currentUser
                  ?.sendEmailVerification();
              Get.snackbar('Email Sent ✉️',
                'Verification link sent to ${user.email}',
                snackPosition:   SnackPosition.BOTTOM,
                backgroundColor: AppTheme.accentSurface,
                colorText:       AppTheme.accentText,
                margin:          const EdgeInsets.all(16),
                borderRadius:    12);
            } catch (_) {}
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent)),
            child: Text('Resend', style: TextStyle(
              color: AppTheme.accentText, fontSize: 11,
              fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 6),
        // Dismiss button
        GestureDetector(
          onTap: () => setState(() => _bannerDismissed = true),
          child: Icon(Icons.close_rounded,
              color: AppTheme.muted, size: 18)),
      ]),
    );
  }

  Widget _buildBody(Map<String, dynamic> data, String role,
      String firstName, String lastName) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(firstName, lastName, role),
      const SizedBox(height: 4),
      _buildRoleBadge(data, role),
      const SizedBox(height: 12),
      _buildHeroCard(data, role),
      _buildSectionTitle('Features'),
      _buildFeatureGrid(role),
      _buildSectionTitle(
          role == 'organizer' ? 'Your Events' : 'Upcoming Games'),
      _buildActivitySection(role),
      const SizedBox(height: 80),
    ]);
  }

  // ── Header ────────────────────────────────

  Widget _buildHeader(String firstName, String lastName, String role) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_greeting,', style: TextStyle(
              color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('$firstName $lastName', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        ]),
        const Spacer(),
        Obx(() {
          final isDark = ThemeController.to.isDark.value;
          return GestureDetector(
            onTap: ThemeController.to.toggleTheme,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: AppTheme.accent, size: 20)));
        }),
        const SizedBox(width: 8),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.notifications_none_rounded,
              color: AppTheme.muted, size: 20)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showAvatarMenu(context, firstName, lastName, role),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.accent2]),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(_initials(firstName, lastName),
              style: const TextStyle(color: AppTheme.buttonFg,
                  fontSize: 13, fontWeight: FontWeight.w800))),
          ),
        ),
      ]),
    );
  }

  // ── Role badge ────────────────────────────

  Widget _buildRoleBadge(Map<String, dynamic> data, String role) {
    final sport = (data['primarySports'] as List?)?.isNotEmpty == true
        ? (data['primarySports'] as List).first as String
        : (data['sportsOrganized'] as List?)?.isNotEmpty == true
            ? (data['sportsOrganized'] as List).first as String : '';
    final emoji = role == 'athlete' ? '🏃'
        : role == 'coach' ? '🧢' : '📋';
    final label = role == 'athlete' ? 'Athlete'
        : role == 'coach' ? 'Coach' : 'Organizer';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent)),
        child: Text(
          '$emoji  ${sport.isNotEmpty ? '$label · $sport' : label}',
          style: TextStyle(color: AppTheme.accentText,
              fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Hero card ─────────────────────────────

  Widget _buildHeroCard(Map<String, dynamic> data, String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border)),
        child: role == 'athlete'
            ? _athleteHero(data)
            : role == 'coach'
                ? _coachHero(data)
                : _organizerHero(data),
      ),
    );
  }

  // ── Athlete hero with REAL rank ────────────

  Widget _athleteHero(Map<String, dynamic> data) {
    final points   = _toInt(data['points']);
    final position = data['position']          as String? ?? '—';
    final years    = data['yearsOfPlaying']    as String? ?? '—';
    final isOpen   = data['openToRecruitment'] as bool?   ?? false;

    return Column(children: [
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTAL POINTS', style: TextStyle(color: AppTheme.sub,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('$points', style: TextStyle(color: AppTheme.accent,
              fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 2),
          Text('Earn points by playing games',
              style: TextStyle(color: AppTheme.sub, fontSize: 10)),
        ]),
        const Spacer(),
        // ── Real city rank ──
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'athlete')
              .get(),
          builder: (context, snap) {
            String rank = '#—';
            if (snap.hasData) {
              final list = snap.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList()
                ..sort((a, b) =>
                    _toInt(b['points']).compareTo(_toInt(a['points'])));
              final idx = list.indexWhere((a) => a['uid'] == _uid);
              if (idx >= 0) rank = '#${idx + 1}';
            }
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent)),
              child: Column(children: [
                Text(rank, style: TextStyle(color: AppTheme.accentText,
                    fontSize: 20, fontWeight: FontWeight.w900)),
                Text('City Rank',
                    style: TextStyle(color: AppTheme.sub, fontSize: 9)),
              ]),
            );
          },
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _StatPill(label: position,
            icon: Icons.sports_basketball_outlined),
        const SizedBox(width: 6),
        _StatPill(label: years, icon: Icons.schedule_rounded),
        const SizedBox(width: 6),
        _StatPill(label: isOpen ? 'Open' : 'Closed',
            icon: Icons.search_rounded, highlighted: isOpen),
      ]),
    ]);
  }

  Widget _coachHero(Map<String, dynamic> data) {
    final level = data['coachingLevel']     as String? ?? '—';
    final org   = data['teamOrganization']  as String? ?? '—';
    final years = data['yearsOfExperience'] as String? ?? '—';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('COACHING LEVEL', style: TextStyle(color: AppTheme.sub,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(level, style: TextStyle(color: AppTheme.accent,
              fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent)),
          child: Column(children: [
            Text(years, style: TextStyle(color: AppTheme.accentText,
                fontSize: 14, fontWeight: FontWeight.w900)),
            Text('Experience',
                style: TextStyle(color: AppTheme.sub, fontSize: 9)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      _StatPill(
          label: org.isEmpty ? 'No organization set' : org,
          icon: Icons.groups_outlined),
    ]);
  }

  Widget _organizerHero(Map<String, dynamic> data) {
    final org     = data['organization']     as String? ?? '—';
    final orgType = data['organizationType'] as String? ?? '—';
    final sports  = (data['sportsOrganized'] as List?)
        ?.map((e) => e.toString()).toList() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ORGANIZATION', style: TextStyle(color: AppTheme.sub,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(org, style: TextStyle(color: AppTheme.accent,
              fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent)),
          child: Column(children: [
            Text(orgType, style: TextStyle(color: AppTheme.accentText,
                fontSize: 13, fontWeight: FontWeight.w900)),
            Text('Type',
                style: TextStyle(color: AppTheme.sub, fontSize: 9)),
          ]),
        ),
      ]),
      if (sports.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: sports.map((s) =>
            _StatPill(label: s, icon: Icons.sports_outlined)).toList()),
      ],
    ]);
  }

  // ── Section title ─────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(title.toUpperCase(), style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }

  // ── Feature grid ──────────────────────────

  Widget _buildFeatureGrid(String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: _features(role).map((f) => _FeatureCard(
          icon:        f['icon'] as IconData,
          title:       f['title'] as String,
          subtitle:    f['subtitle'] as String,
          isHighlight: f['highlight'] as bool,
          onTap: () => _onFeatureTap(f['title'] as String),
        )).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _features(String role) {
    switch (role) {
      case 'organizer':
        return [
          {'icon': Icons.add_circle_outline_rounded, 'title': 'Add Stats',
            'subtitle': 'Record game stats',   'highlight': true},
          {'icon': Icons.calendar_today_outlined,    'title': 'My Events',
            'subtitle': 'Create tournaments',  'highlight': false},
          {'icon': Icons.leaderboard_rounded,        'title': 'Leaderboard',
            'subtitle': 'View rankings',       'highlight': false},
          {'icon': Icons.location_on_outlined,       'title': 'Venues',
            'subtitle': 'Manage locations',    'highlight': false},
        ];
      case 'coach':
        return [
          {'icon': Icons.search_rounded,         'title': 'Scout Athletes',
            'subtitle': 'Find talent',          'highlight': true},
          {'icon': Icons.leaderboard_rounded,    'title': 'Leaderboard',
            'subtitle': 'City rankings',        'highlight': false},
          {'icon': Icons.location_on_outlined,   'title': 'Find Games',
            'subtitle': 'Browse venues',        'highlight': false},
          {'icon': Icons.person_outline_rounded, 'title': 'My Profile',
            'subtitle': 'Edit your info',       'highlight': false},
        ];
      default:
        return [
          {'icon': Icons.bar_chart_rounded,      'title': 'My Dashboard',
            'subtitle': 'View your stats',      'highlight': true},
          {'icon': Icons.leaderboard_rounded,    'title': 'Leaderboard',
            'subtitle': 'See city rankings',    'highlight': false},
          {'icon': Icons.location_on_outlined,   'title': 'Find Games',
            'subtitle': 'Browse venues',        'highlight': false},
          {'icon': Icons.person_outline_rounded, 'title': 'My Profile',
            'subtitle': 'Edit your info',       'highlight': false},
        ];
    }
  }

  // ── Activity section ──────────────────────

  Widget _buildActivitySection(String role) {
    if (role == 'organizer') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('organizerId', isEqualTo: _uid)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _EmptyCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'No events yet',
                  subtitle: 'Tap + to create your first event');
            }
            final events = snapshot.data!.docs.toList()..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });
            return _EventList(events: events.take(3).toList());
          },
        ),
      );
    }

    final stream = role == 'athlete'
        ? FirebaseFirestore.instance.collection('events')
            .where('playerUids', arrayContains: _uid)
            .where('status', isEqualTo: 'upcoming')
            .limit(10).snapshots()
        : FirebaseFirestore.instance.collection('events')
            .where('isPublic', isEqualTo: true)
            .where('status', isEqualTo: 'upcoming')
            .limit(10).snapshots();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _EmptyCard(
              icon: Icons.sports_rounded,
              title: role == 'athlete'
                  ? "You're not in any upcoming events"
                  : 'No upcoming games yet',
              subtitle: role == 'athlete'
                  ? 'An organizer will add you to events'
                  : 'Check back soon');
          }
          final events = snapshot.data!.docs.toList()..sort((a, b) {
            final aT = (a.data() as Map)['eventDate'] as Timestamp?;
            final bT = (b.data() as Map)['eventDate'] as Timestamp?;
            if (aT == null || bT == null) return 0;
            return aT.compareTo(bT);
          });
          return _EventList(events: events.take(3).toList());
        },
      ),
    );
  }

  // ── Bottom nav ────────────────────────────

  Widget _buildBottomNav(String role) {
    final items = _navItems(role);
    return Container(
      decoration: BoxDecoration(color: AppTheme.card,
          border: Border(top: BorderSide(color: AppTheme.border))),
      child: SafeArea(top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final active = i == _navIndex;
            return GestureDetector(
              onTap: () => _onNavTap(i, role),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i]['icon'] as IconData,
                    color: active ? AppTheme.accent : AppTheme.muted,
                    size: 22),
                  const SizedBox(height: 3),
                  Text(items[i]['label'] as String, style: TextStyle(
                    color: active ? AppTheme.accent : AppTheme.muted,
                    fontSize: 9, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _navItems(String role) {
    switch (role) {
      case 'organizer':
        return [
          {'icon': Icons.home_rounded,               'label': 'Home'},
          {'icon': Icons.add_circle_outline_rounded,  'label': 'Add Stats'},
          {'icon': Icons.calendar_today_outlined,     'label': 'Events'},
          {'icon': Icons.location_on_outlined,        'label': 'Venues'},
          {'icon': Icons.person_outline_rounded,      'label': 'Profile'},
        ];
      case 'coach':
        return [
          {'icon': Icons.home_rounded,           'label': 'Home'},
          {'icon': Icons.search_rounded,         'label': 'Scout'},
          {'icon': Icons.leaderboard_rounded,    'label': 'Rankings'},
          {'icon': Icons.location_on_outlined,   'label': 'Games'},
          {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
        ];
      default:
        return [
          {'icon': Icons.home_rounded,           'label': 'Home'},
          {'icon': Icons.bar_chart_rounded,      'label': 'Stats'},
          {'icon': Icons.leaderboard_rounded,    'label': 'Discover'},
          {'icon': Icons.location_on_outlined,   'label': 'Games'},
          {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
        ];
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<QueryDocumentSnapshot> events;
  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: events.asMap().entries.map((e) {
        final isLast = e.key == events.length - 1;
        final ev     = e.value.data() as Map<String, dynamic>;
        final status = ev['status'] as String? ?? 'upcoming';
        final date   = ev['eventDate'] as Timestamp?;
        final fmtDate = date != null
            ? DateFormat('MMM dd').format(date.toDate()) : '—';
        return Container(
          decoration: BoxDecoration(border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: AppTheme.border))),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent)),
              child: Icon(Icons.emoji_events_outlined,
                  color: AppTheme.accent, size: 18)),
            title: Text(ev['name'] as String? ?? '',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${ev['sport']} · ${ev['venue']} · $fmtDate',
              style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: status == 'draft'
                    ? AppTheme.cardNested : AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: status == 'draft'
                      ? AppTheme.border : AppTheme.accent)),
              child: Text(status.toUpperCase(), style: TextStyle(
                color: status == 'draft'
                    ? AppTheme.muted : AppTheme.accentText,
                fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }).toList()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _EmptyCard({required this.icon,
      required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border)),
    child: Center(child: Column(children: [
      Icon(icon, color: AppTheme.muted, size: 32),
      const SizedBox(height: 8),
      Text(title, style: TextStyle(color: AppTheme.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(color: AppTheme.muted, fontSize: 11),
          textAlign: TextAlign.center),
    ])),
  );
}

class _StatPill extends StatelessWidget {
  final String label; final IconData icon; final bool highlighted;
  const _StatPill({required this.label, required this.icon,
      this.highlighted = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: highlighted ? AppTheme.accentSurface : AppTheme.cardNested,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: highlighted ? AppTheme.accent : AppTheme.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12,
          color: highlighted ? AppTheme.accent : AppTheme.muted),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        color: highlighted ? AppTheme.accentText : AppTheme.muted,
        fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final bool isHighlight; final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.title,
      required this.subtitle, required this.isHighlight,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight ? AppTheme.accentSurface : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight ? AppTheme.accent : AppTheme.border,
          width: isHighlight ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon,
            color: isHighlight ? AppTheme.accent : AppTheme.muted,
            size: 24),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(
          color: isHighlight ? AppTheme.accentText : AppTheme.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(color: AppTheme.sub, fontSize: 11)),
      ]),
    ),
  );
}