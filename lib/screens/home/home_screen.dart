// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_notification.dart';
import '../../models/team_invite.dart';
import '../../services/notification_service.dart';
import '../../services/team_service.dart';
import '../../utils/firestore_helpers.dart';

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
                Icon(LucideIcons.logOut, color: Color(0xFFFF5C5C), size: 20),
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

  // ── Notifications sheet ───────────────────
  // Same bottom-sheet pattern as _showAvatarMenu above, for
  // consistency. Marks everything read once the sheet opens.

  void _showNotificationsSheet(BuildContext context) {
    NotificationService.markAllRead(_uid);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Notifications', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmClearAllNotifications(context),
                child: Text('Clear All', style: TextStyle(
                    color: AppTheme.sub, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: _uid)
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${snapshot.error}',
                        style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.bell,
                            color: AppTheme.muted, size: 40),
                        const SizedBox(height: 10),
                        Text('No notifications yet', style: TextStyle(
                            color: AppTheme.sub, fontSize: 13)),
                      ]),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final n = AppNotification.fromDoc(docs[i]);
                    return GestureDetector(
                      onTap: () {
                        Get.back();
                        if (n.type == NotificationType.teamInvite) {
                          Get.toNamed('/team/invites',
                              arguments: {'inviteId': n.relatedId});
                        }
                      },
                      child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: n.read
                              ? AppTheme.cardNested
                              : AppTheme.accentSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: n.read
                                  ? AppTheme.border
                                  : AppTheme.accent)),
                      child: Row(children: [
                        Icon(
                            n.type == NotificationType.statsAdded
                                ? LucideIcons.barChart2
                                : n.type == NotificationType.eventAdded
                                    ? LucideIcons.calendarCheck
                                    : n.type == NotificationType.teamInvite
                                        ? LucideIcons.userPlus
                                        : n.type == NotificationType.teamFull
                                            ? LucideIcons.userX
                                            : LucideIcons.bell,
                            color: n.read ? AppTheme.muted : AppTheme.accent,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(n.body, style: TextStyle(
                                  color: AppTheme.sub, fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmClearAllNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Clear all notifications?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
        content: Text(
            'This removes every notification and can\'t be undone.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(
                color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              NotificationService.deleteAll(_uid);
            },
            child: const Text('Clear All', style: TextStyle(
                color: Color(0xFFFF5C5C), fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── View All sheets ────────────────────────
  // Same DraggableScrollableSheet pattern as _showNotificationsSheet,
  // reusing the same query shapes as the home screen preview but
  // without the small take(3)/limit(3) cap.

  void _showAllEventsSheet(BuildContext context, String role) {
    final Stream<QuerySnapshot> stream = role == 'organizer'
        ? FirebaseFirestore.instance
            .collection('events')
            .where('organizerId', isEqualTo: _uid)
            .snapshots()
        : role == 'athlete'
            ? FirebaseFirestore.instance
                .collection('events')
                .where('playerUids', arrayContains: _uid)
                .where('status', isEqualTo: 'upcoming')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('events')
                .where('isPublic', isEqualTo: true)
                .where('status', isEqualTo: 'upcoming')
                .snapshots();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text(role == 'organizer' ? 'Your Events' : 'Upcoming Games',
                  style: TextStyle(color: AppTheme.textPrimary,
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
                }
                var docs = snapshot.data?.docs.toList() ?? [];
                if (role != 'organizer') {
                  final now = Timestamp.now();
                  docs = docs.where((doc) {
                    final t = asTimestamp((doc.data() as Map)['eventDate']);
                    return t == null || t.compareTo(now) >= 0;
                  }).toList();
                }
                docs.sort((a, b) {
                  final field = role == 'organizer' ? 'createdAt' : 'eventDate';
                  final aT = asTimestamp((a.data() as Map)[field]);
                  final bT = asTimestamp((b.data() as Map)[field]);
                  if (aT == null || bT == null) return 0;
                  return role == 'organizer'
                      ? bT.compareTo(aT)
                      : aT.compareTo(bT);
                });
                if (docs.isEmpty) {
                  return Center(
                    child: Text('Nothing here yet', style: TextStyle(
                        color: AppTheme.sub, fontSize: 13)),
                  );
                }
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: _EventList(events: docs),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showAllActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Recent Activity', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stats')
                  .where('athleteId', isEqualTo: _uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${snapshot.error}',
                        style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text('No stats yet', style: TextStyle(
                        color: AppTheme.sub, fontSize: 13)),
                  );
                }
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Container(
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border)),
                    child: Column(
                      children: docs.asMap().entries.map((e) {
                        final isLast = e.key == docs.length - 1;
                        final s = e.value.data() as Map<String, dynamic>;
                        return _ActivityEntryTile(
                          data: s,
                          showDivider: !isLast,
                          statBreakdown: _statBreakdown,
                          relativeDate: _relativeDate,
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

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
      case 'Record Match':   Get.toNamed('/matches/record'); return;
      case 'My Events':      Get.toNamed('/events/create'); return;
      case 'Leaderboard':    Get.toNamed('/leaderboard');   return;
      case 'Scout Athletes': Get.toNamed('/scout');         return;
      case 'My Dashboard':   Get.toNamed('/dashboard');     return;
      case 'My Profile':     Get.toNamed('/profile');       return;
      case 'Find Games':     Get.toNamed('/venues');        return;
      case 'Venues':         Get.toNamed('/venues');        return;
      case 'My Team':        Get.toNamed('/team/roster');   return;
      case 'Team Invites':   Get.toNamed('/team/invites');  return;
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
                  child: const Icon(LucideIcons.plus))
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
          child: Icon(LucideIcons.x,
              color: AppTheme.muted, size: 18)),
      ]),
    );
  }

  Widget _buildBody(Map<String, dynamic> data, String role,
      String firstName, String lastName) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(data, firstName, lastName, role),
      const SizedBox(height: 4),
      _buildRoleBadge(data, role),
      const SizedBox(height: 12),
      _buildHeroCard(data, role),
      if (role == 'athlete') ...[
        _buildSectionTitle('My Team'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildAthleteTeamSection(),
        ),
      ],
      // CHANGED: athlete's Features grid duplicated the bottom nav
      // tab-for-tab (Dashboard=Stats, Leaderboard=Discover, Find
      // Games=Games, Profile=Profile). Replaced with a Recent
      // Activity section showing real content instead of a second
      // way to reach the same 4 screens. Coach's grid had the same
      // problem (Scout/Rankings/Games/Profile all already in the
      // bottom nav) minus My Team, so it's replaced with a live team
      // section below. Organizer's grid had the same problem (Add
      // Stats/Events/Venues/Profile all already in the bottom nav)
      // minus Leaderboard (dropped — not an event-admin concern), so
      // it's replaced with a Next Event panel showing their soonest
      // upcoming event and its roster.
      if (role == 'athlete') ...[
        _buildSectionTitle('Recent Activity',
            onViewAll: () => _showAllActivitySheet(context)),
        _buildRecentActivity(data),
      ] else if (role == 'coach') ...[
        _buildSectionTitle('My Team'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildCoachTeamSection(data),
        ),
      ] else if (role == 'organizer') ...[
        _buildSectionTitle('Next Event'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildOrganizerNextEventSection(),
        ),
      ] else ...[
        _buildSectionTitle('Features'),
        _buildFeatureGrid(role),
      ],
      _buildSectionTitle(
          role == 'organizer' ? 'Your Events' : 'Upcoming Games',
          onViewAll: () => _showAllEventsSheet(context, role)),
      _buildActivitySection(role),
      const SizedBox(height: 80),
    ]);
  }

  // ── Recent Activity (athlete only) ────────

  Widget _buildRecentActivity(Map<String, dynamic> data) {
    // CHANGED: dropped the "You're #1" progress strip — it duplicated
    // the City Rank already shown in the hero card above.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildActivityList(),
    );
  }

  /// Turns a stat entry's `stats` map into a compact per-sport
  /// summary line, e.g. "12 PTS · 5 REB · 3 AST" (basketball),
  /// "8 kills · 2 aces" (volleyball), "Win · 2 sets" (badminton).
  String _statBreakdown(String sport, Map<String, dynamic> stats) {
    switch (sport) {
      case 'Basketball':
        final parts = <String>[];
        if (_toInt(stats['points']) > 0) {
          parts.add('${_toInt(stats['points'])} PTS');
        }
        if (_toInt(stats['rebounds']) > 0) {
          parts.add('${_toInt(stats['rebounds'])} REB');
        }
        if (_toInt(stats['assists']) > 0) {
          parts.add('${_toInt(stats['assists'])} AST');
        }
        if (_toInt(stats['steals']) > 0) {
          parts.add('${_toInt(stats['steals'])} STL');
        }
        if (_toInt(stats['blocks']) > 0) {
          parts.add('${_toInt(stats['blocks'])} BLK');
        }
        return parts.isEmpty ? '—' : parts.join(' · ');
      case 'Volleyball':
        final parts = <String>[];
        if (_toInt(stats['kills']) > 0) {
          parts.add('${_toInt(stats['kills'])} kills');
        }
        if (_toInt(stats['aces']) > 0) {
          parts.add('${_toInt(stats['aces'])} aces');
        }
        if (_toInt(stats['digs']) > 0) {
          parts.add('${_toInt(stats['digs'])} digs');
        }
        if (_toInt(stats['blocks']) > 0) {
          parts.add('${_toInt(stats['blocks'])} blocks');
        }
        return parts.isEmpty ? '—' : parts.join(' · ');
      case 'Badminton':
        final won = stats['matchWon'] as bool? ?? false;
        final parts = <String>[won ? 'Win' : 'Loss'];
        if (_toInt(stats['setsWon']) > 0) {
          parts.add('${_toInt(stats['setsWon'])} sets');
        }
        return parts.join(' · ');
      default:
        return '';
    }
  }

  Widget _buildActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stats')
          .where('athleteId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2)));
        }
        // Surface the real error instead of silently showing "No
        // stats yet". A missing composite index (athleteId +
        // createdAt) is the most common cause here — Firestore
        // throws a FAILED_PRECONDITION with a direct console link
        // to auto-create it.
        if (snapshot.hasError) {
          return _EmptyCard(
            icon: LucideIcons.alertCircle,
            title: 'Could not load activity',
            subtitle: '${snapshot.error}',
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyCard(
            icon: LucideIcons.barChart2,
            title: 'No stats yet',
            subtitle:
                'Your coach or organizer will add them after your first game',
          );
        }
        return Container(
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(
            children: docs.asMap().entries.map((e) {
              final isLast = e.key == docs.length - 1;
              final s = e.value.data() as Map<String, dynamic>;
              return _ActivityEntryTile(
                data: s,
                showDivider: !isLast,
                statBreakdown: _statBreakdown,
                relativeDate: _relativeDate,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return DateFormat('MMM dd').format(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ── Header ────────────────────────────────
  // CHANGED: removed the dark/light-mode toggle button that used to
  // sit here (ThemeController.to.toggleTheme). That control now
  // belongs in the Profile screen instead of the home header.

  Widget _buildHeader(Map<String, dynamic> data, String firstName,
      String lastName, String role) {
    final photoUrl = data['photoUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        // CHANGED: avatar moved to the left, paired with the
        // greeting — now shows the uploaded profile photo (falls
        // back to initials) instead of always being initials-only,
        // and instead of sitting on the far right.
        GestureDetector(
          onTap: () => _showAvatarMenu(context, firstName, lastName, role),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.accent2]),
              borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(_initials(firstName, lastName),
                              style: const TextStyle(
                                  color: AppTheme.buttonFg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800))))
                  : Center(child: Text(_initials(firstName, lastName),
                      style: const TextStyle(color: AppTheme.buttonFg,
                          fontSize: 15, fontWeight: FontWeight.w800))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_greeting,', style: TextStyle(
              color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('$firstName $lastName', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => _showNotificationsSheet(context),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: _uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final unread = snap.data?.docs.length ?? 0;
              return Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border)),
                  child: Icon(LucideIcons.bell,
                      color: AppTheme.muted, size: 20)),
                if (unread > 0)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF5C5C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.bg, width: 1.5)),
                      child: Center(
                        child: Text(unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
              ]);
            },
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
            icon: LucideIcons.activity),
        const SizedBox(width: 6),
        _StatPill(label: years, icon: LucideIcons.clock),
        const SizedBox(width: 6),
        _StatPill(label: isOpen ? 'Open' : 'Closed',
            icon: LucideIcons.search, highlighted: isOpen),
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
          icon: LucideIcons.users),
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
            _StatPill(label: s, icon: LucideIcons.activity)).toList()),
      ],
    ]);
  }

  // ── Section title ─────────────────────────

  Widget _buildSectionTitle(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Text(title.toUpperCase(), style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const Spacer(),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text('View All', style: TextStyle(
                color: AppTheme.accent, fontSize: 11,
                fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  // ── Team invites entry (athlete only) ─────
  // Always-visible card so athletes have a path to their invites even
  // when there are none pending — the athlete Features grid was removed
  // in favor of Recent Activity, so this is their only route to
  // /team/invites besides tapping a team-invite notification.

  // ── My Team section (athlete) ──────────────
  // Distinct from the coach's roster-management card below: an athlete's
  // primary relationship is "who's my coach and how many teammates do I
  // have," not a roster they manage. Pending invites — previously this
  // slot's only job — are now one of three states rather than a
  // permanent fixture, since they still live inside the destination flow
  // (TeamInvitesScreen's own "PENDING INVITES" section).

  Widget _buildAthleteTeamSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamAthleteTeams(_uid),
      builder: (context, teamsSnap) {
        final teams = (teamsSnap.data?.docs ?? [])
            .map((d) =>
                TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        return StreamBuilder<QuerySnapshot>(
          stream: TeamService.streamReceivedPending(_uid),
          builder: (context, pendingSnap) {
            final pendingDocs = pendingSnap.data?.docs ?? [];
            if (teams.isNotEmpty) {
              return _buildOnTeamCard(teams, pendingDocs.length);
            }
            if (pendingDocs.isNotEmpty) {
              final first = TeamInvite.fromMap(pendingDocs.first.id,
                  pendingDocs.first.data() as Map<String, dynamic>);
              return _buildInvitedCard(pendingDocs.length, first);
            }
            return _buildNoTeamCard();
          },
        );
      },
    );
  }

  Widget _buildOnTeamCard(List<TeamInvite> teams, int pendingCount) {
    final team = teams.first;
    final initials = team.coachName.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2)
        .map((p) => p[0]).join().toUpperCase();

    return GestureDetector(
      onTap: () {
        if (teams.length == 1 && pendingCount == 0) {
          Get.toNamed('/team/mine', arguments: {
            'coachId': team.coachId,
            'coachName': team.coachName,
            'teamName': team.teamName,
          });
        } else {
          Get.toNamed('/team/invites');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(team.teamName, style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15,
                fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            FutureBuilder<int>(
              future: TeamService.rosterCountFor(team.coachId),
              builder: (context, snap) {
                final teammates = ((snap.data ?? 1) - 1).clamp(0, 999);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.accentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent)),
                  child: Text(
                      '$teammates teammate${teammates == 1 ? '' : 's'}',
                      style: TextStyle(color: AppTheme.accentText,
                          fontSize: 11, fontWeight: FontWeight.w800)),
                );
              },
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppTheme.accent, AppTheme.accent2]),
                shape: BoxShape.circle),
              child: Center(child: Text(initials, style: const TextStyle(
                  color: AppTheme.buttonFg, fontSize: 14,
                  fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.coachName, style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text('Your Coach',
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('View Team', style: TextStyle(
                color: AppTheme.accent, fontSize: 13,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.accent, size: 16),
          ]),
        ]),
      ),
    );
  }

  Widget _buildInvitedCard(int pendingCount, TeamInvite first) {
    return GestureDetector(
      onTap: () => Get.toNamed('/team/invites'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent, width: 1.5)),
        child: Row(children: [
          Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent)),
              child: Icon(LucideIcons.userPlus,
                  color: AppTheme.accent, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("You're Invited!", style: TextStyle(
                  color: AppTheme.accentText, fontSize: 14,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  pendingCount > 1
                      ? '$pendingCount pending invites'
                      : 'Coach ${first.coachName} wants you for ${first.teamName}',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.accentText, size: 20),
        ]),
      ),
    );
  }

  Widget _buildNoTeamCard() {
    return GestureDetector(
      onTap: () => Get.toNamed('/team/invites'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Icon(Icons.groups_outlined,
                  color: AppTheme.muted, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No Team Yet', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Invites from coaches will appear here',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12)),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }

  // ── My Team section (coach only) ──────────
  // Replaces the coach Features grid: Scout/Rankings/Games/Profile are
  // already one tap away via the bottom nav, so the home screen gives
  // that space to the coach's actual daily workflow — their roster and
  // outstanding invites — instead of duplicating nav entries.

  Widget _buildCoachTeamSection(Map<String, dynamic> data) {
    final teamName = data['teamOrganization'] as String? ?? 'Your Team';

    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(_uid),
      builder: (context, rosterSnap) {
        final roster = (rosterSnap.data?.docs ?? [])
            .map((d) =>
                TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        final isFull = roster.length >= TeamService.maxPlayers;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(teamName, style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isFull
                        ? const Color(0xFFFF5C5C).withValues(alpha: 0.12)
                        : AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isFull
                            ? const Color(0xFFFF5C5C)
                            : AppTheme.accent)),
                child: Text('${roster.length}/${TeamService.maxPlayers}', style: TextStyle(
                    color: isFull
                        ? const Color(0xFFFF5C5C)
                        : AppTheme.accentText,
                    fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 12),
            if (roster.isEmpty)
              Column(children: [
                Icon(Icons.groups_outlined, color: AppTheme.muted, size: 28),
                const SizedBox(height: 8),
                Text('No athletes on your roster yet', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => Get.toNamed('/scout'),
                  child: Text('Invite athletes from Scout', style: TextStyle(
                      color: AppTheme.accent, fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ),
              ])
            else
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: roster.length > 6 ? 7 : roster.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (roster.length > 6 && i == 6) {
                      return Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: AppTheme.cardNested,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.border)),
                        child: Center(child: Text('+${roster.length - 6}',
                            style: TextStyle(color: AppTheme.sub,
                                fontSize: 11, fontWeight: FontWeight.w800))));
                    }
                    final m = roster[i];
                    final initials = m.athleteName.trim().split(' ')
                        .where((p) => p.isNotEmpty).take(2)
                        .map((p) => p[0]).join().toUpperCase();
                    return Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.accent, AppTheme.accent2]),
                        shape: BoxShape.circle),
                      child: ClipOval(
                        child: m.athletePhotoUrl != null &&
                                m.athletePhotoUrl!.isNotEmpty
                            ? Image.network(m.athletePhotoUrl!,
                                fit: BoxFit.cover, width: 36, height: 36,
                                errorBuilder: (_, __, ___) => Center(
                                    child: Text(initials, style: const TextStyle(
                                        color: AppTheme.buttonFg, fontSize: 12,
                                        fontWeight: FontWeight.w800))))
                            : Center(child: Text(initials, style: const TextStyle(
                                color: AppTheme.buttonFg, fontSize: 12,
                                fontWeight: FontWeight.w800))),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: TeamService.streamSentPending(_uid),
              builder: (context, pendingSnap) {
                final pending = pendingSnap.data?.docs.length ?? 0;
                if (pending == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(LucideIcons.mail, color: AppTheme.muted, size: 14),
                    const SizedBox(width: 6),
                    Text('$pending pending invite${pending == 1 ? '' : 's'}',
                        style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                  ]),
                );
              },
            ),
            GestureDetector(
              onTap: () => Get.toNamed('/team/roster'),
              child: Row(children: [
                Text('View Full Roster', style: TextStyle(
                    color: AppTheme.accent, fontSize: 13,
                    fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.accent, size: 16),
              ]),
            ),
          ]),
        );
      },
    );
  }

  // ── Next Event section (organizer only) ───
  // Replaces the organizer Features grid: Add Stats/Events/Venues/Profile
  // are already one tap away via the bottom nav, so the home screen gives
  // that space to the organizer's actual admin workflow — their soonest
  // upcoming event and its registration status — instead of a generic
  // tile grid.

  Widget _buildOrganizerNextEventSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: _uid)
          .where('status', isEqualTo: 'upcoming')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aT = asTimestamp((a.data() as Map)['eventDate']);
            final bT = asTimestamp((b.data() as Map)['eventDate']);
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return aT.compareTo(bT);
          });

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              Icon(LucideIcons.calendar, color: AppTheme.muted, size: 28),
              const SizedBox(height: 8),
              Text('No upcoming events', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => Get.toNamed('/events/create'),
                child: Text('Create your first event', style: TextStyle(
                    color: AppTheme.accent, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }

        final doc         = docs.first;
        final ev           = doc.data() as Map<String, dynamic>;
        final name         = ev['name'] as String? ?? 'Untitled Event';
        final playerCount  = ev['playerCount'] as int? ?? 0;
        // 'No limit' events are created with maxPlayers left null.
        final maxPlayers   = ev['maxPlayers'] as int?;
        final isFull       = maxPlayers != null && playerCount >= maxPlayers;
        final countLabel   =
            maxPlayers != null ? '$playerCount/$maxPlayers' : '$playerCount';
        final date         = asTimestamp(ev['eventDate']);
        final fmtDate      = date != null
            ? DateFormat('MMM dd, h:mm a').format(date.toDate())
            : 'Date TBD';
        final sport        = ev['sport'] as String? ?? '';
        final venue        = ev['venue'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isFull
                        ? AppTheme.accentSurface
                        : AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isFull ? AppTheme.accent : AppTheme.border)),
                child: Text(countLabel, style: TextStyle(
                    color: isFull ? AppTheme.accentText : AppTheme.sub,
                    fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('$sport · $venue · $fmtDate',
                style: TextStyle(color: AppTheme.sub, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(children: [
              GestureDetector(
                onTap: () => Get.toNamed('/events/detail',
                    arguments: {'eventId': doc.id}),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Roster', style: TextStyle(
                      color: AppTheme.accent, fontSize: 13,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accent, size: 16),
                ]),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => Get.toNamed('/matches/record'),
                child: Text('Record Results', style: TextStyle(
                    color: AppTheme.sub, fontSize: 13,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        );
      },
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

  // Only reached for a role that isn't athlete/coach/organizer — a
  // defensive fallback, not a real destination for any current role.
  List<Map<String, dynamic>> _features(String role) {
    return [
      {'icon': LucideIcons.barChart2,      'title': 'My Dashboard',
        'subtitle': 'View your stats',      'highlight': true},
      {'icon': LucideIcons.trophy,    'title': 'Leaderboard',
        'subtitle': 'See city rankings',    'highlight': false},
      {'icon': LucideIcons.mapPin,   'title': 'Find Games',
        'subtitle': 'Browse venues',        'highlight': false},
      {'icon': LucideIcons.user, 'title': 'My Profile',
        'subtitle': 'Edit your info',       'highlight': false},
      {'icon': LucideIcons.userPlus, 'title': 'Team Invites',
        'subtitle': 'Invites from coaches', 'highlight': false},
    ];
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
                  icon: LucideIcons.calendar,
                  title: 'No events yet',
                  subtitle: 'Tap + to create your first event');
            }
            final events = snapshot.data!.docs.toList()..sort((a, b) {
              final aT = asTimestamp((a.data() as Map)['createdAt']);
              final bT = asTimestamp((b.data() as Map)['createdAt']);
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
              icon: LucideIcons.activity,
              title: role == 'athlete'
                  ? "You're not in any upcoming events"
                  : 'No upcoming games yet',
              subtitle: role == 'athlete'
                  ? 'An organizer will add you to events'
                  : 'Check back soon');
          }
          // CHANGED: 'status' is a field the organizer sets manually
          // and doesn't update itself once the event date passes, so
          // a game stayed "upcoming" indefinitely after it happened.
          // Filtering by the real eventDate here removes anything
          // that's already occurred, regardless of that field.
          final now = Timestamp.now();
          final events = snapshot.data!.docs.where((doc) {
            final t = asTimestamp((doc.data() as Map)['eventDate']);
            return t == null || t.compareTo(now) >= 0;
          }).toList()..sort((a, b) {
            final aT = asTimestamp((a.data() as Map)['eventDate']);
            final bT = asTimestamp((b.data() as Map)['eventDate']);
            if (aT == null || bT == null) return 0;
            return aT.compareTo(bT);
          });
          if (events.isEmpty) {
            return _EmptyCard(
              icon: LucideIcons.activity,
              title: role == 'athlete'
                  ? "You're not in any upcoming events"
                  : 'No upcoming games yet',
              subtitle: role == 'athlete'
                  ? 'An organizer will add you to events'
                  : 'Check back soon');
          }
          return _EventList(events: events.take(3).toList());
        },
      ),
    );
  }

  // ── Bottom nav ────────────────────────────
  // CHANGED: redesigned as a floating pill (margin on all sides,
  // fully rounded), icon-only tabs, and a filled circular badge
  // behind the active icon instead of just a color change — matches
  // the modern Android nav pattern you referenced.

  Widget _buildBottomNav(String role) {
    final items = _navItems(role);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            final active = i == _navIndex;
            return GestureDetector(
              onTap: () => _onNavTap(i, role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  items[i]['icon'] as IconData,
                  color: active ? AppTheme.buttonFg : AppTheme.muted,
                  size: 22,
                ),
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
          {'icon': LucideIcons.home,        'label': 'Home'},
          {'icon': LucideIcons.plusCircle,  'label': 'Add Stats'},
          {'icon': LucideIcons.calendar,    'label': 'Events'},
          {'icon': LucideIcons.mapPin,      'label': 'Venues'},
          {'icon': LucideIcons.user,        'label': 'Profile'},
        ];
      case 'coach':
        return [
          {'icon': LucideIcons.home,    'label': 'Home'},
          {'icon': LucideIcons.search,  'label': 'Scout'},
          {'icon': LucideIcons.trophy,  'label': 'Rankings'},
          {'icon': LucideIcons.mapPin,  'label': 'Games'},
          {'icon': LucideIcons.user,    'label': 'Profile'},
        ];
      default:
        return [
          {'icon': LucideIcons.home,     'label': 'Home'},
          {'icon': LucideIcons.barChart2,'label': 'Stats'},
          {'icon': LucideIcons.compass,  'label': 'Discover'},
          {'icon': LucideIcons.mapPin,   'label': 'Games'},
          {'icon': LucideIcons.user,     'label': 'Profile'},
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
        final date   = asTimestamp(ev['eventDate']);
        final fmtDate = date != null
            ? DateFormat('MMM dd').format(date.toDate()) : '—';
        return Container(
          decoration: BoxDecoration(border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: AppTheme.border))),
          child: ListTile(
            dense: true,
            onTap: () => Get.toNamed('/events/detail',
                arguments: {'eventId': e.value.id}),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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

/// A recent-activity row that's tappable to expand into the full
/// stat breakdown for that entry (all fields, not just the non-zero
/// highlights shown when collapsed) — lets an athlete actually track
/// their per-game numbers, not just the points total.
class _ActivityEntryTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showDivider;
  final String Function(String sport, Map<String, dynamic> stats)
      statBreakdown;
  final String Function(DateTime date) relativeDate;

  const _ActivityEntryTile({
    required this.data,
    required this.showDivider,
    required this.statBreakdown,
    required this.relativeDate,
  });

  @override
  State<_ActivityEntryTile> createState() => _ActivityEntryTileState();
}

class _ActivityEntryTileState extends State<_ActivityEntryTile> {
  bool _expanded = false;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  /// Full stat rows for the expanded view — every tracked field for
  /// the sport, in the same order the Add Stats form collects them,
  /// even when a value is 0 (so it reads as a real box score).
  List<MapEntry<String, String>> _fullStatRows(
      String sport, Map<String, dynamic> stats) {
    switch (sport) {
      case 'Basketball':
        return [
          MapEntry('Points', '${_toInt(stats['points'])}'),
          MapEntry('Assists', '${_toInt(stats['assists'])}'),
          MapEntry('Rebounds', '${_toInt(stats['rebounds'])}'),
          MapEntry('Steals', '${_toInt(stats['steals'])}'),
          MapEntry('Blocks', '${_toInt(stats['blocks'])}'),
          MapEntry('Turnovers', '${_toInt(stats['turnovers'])}'),
        ];
      case 'Volleyball':
        return [
          MapEntry('Kills', '${_toInt(stats['kills'])}'),
          MapEntry('Aces', '${_toInt(stats['aces'])}'),
          MapEntry('Assists', '${_toInt(stats['assists'])}'),
          MapEntry('Digs', '${_toInt(stats['digs'])}'),
          MapEntry('Blocks', '${_toInt(stats['blocks'])}'),
        ];
      case 'Badminton':
        final won = stats['matchWon'] as bool? ?? false;
        return [
          MapEntry('Result', won ? 'Win' : 'Loss'),
          MapEntry('Sets Won', '${_toInt(stats['setsWon'])}'),
          MapEntry('Points Scored', '${_toInt(stats['pointsScored'])}'),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;
    final pts = _toInt(s['pointsAwarded']);
    final sport = s['sport'] as String? ?? '';
    final statsMap = (s['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final breakdown = widget.statBreakdown(sport, statsMap);
    final ts = s['createdAt'] as Timestamp?;
    final when = ts != null ? widget.relativeDate(ts.toDate()) : '';
    final notes = (s['notes'] as String? ?? '').trim();
    final rows = _fullStatRows(sport, statsMap);

    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: widget.showDivider
                  ? BorderSide(color: AppTheme.border)
                  : BorderSide.none)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['eventName'] as String? ?? '',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$sport · $when',
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                    if (breakdown.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(breakdown,
                          style:
                              TextStyle(color: AppTheme.muted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('+$pts',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(LucideIcons.chevronDown,
                    color: AppTheme.muted, size: 20),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rows
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.key,
                                      style: TextStyle(
                                          color: AppTheme.sub, fontSize: 9)),
                                  Text(r.value,
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Notes',
                        style: TextStyle(
                            color: AppTheme.sub,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(notes,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
  class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: Center(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.muted, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
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

// CHANGED: isHighlight no longer draws a full accent border + tinted
// background across the whole card (that read as a "selected" state
// since it's visually identical to the selection styling used on the
// Sport/Role picker cards). Instead every card now shares the same
// neutral card border, and emphasis lives in the icon itself — a
// solid accent-filled badge vs. a plain outlined one. Same "primary
// action" signal, without implying the card is toggled/selected.
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
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: isHighlight ? AppTheme.accent : AppTheme.cardNested,
            borderRadius: BorderRadius.circular(10),
            border: isHighlight
                ? null
                : Border.all(color: AppTheme.border)),
          child: Icon(icon,
              color: isHighlight ? AppTheme.buttonFg : AppTheme.muted,
              size: 18),
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(color: AppTheme.sub, fontSize: 11)),
      ]),
    ),
  );
}