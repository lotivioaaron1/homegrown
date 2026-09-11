// lib/screens/home/home_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/query_limits.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_notification.dart';
import '../../models/team_invite.dart';
import '../../models/tournament.dart';
import '../../services/event_reminder_service.dart';
import '../../services/notification_service.dart';
import '../../services/ranking_service.dart';
import '../../services/team_service.dart';
import '../../services/tournament_service.dart';
import '../../widgets/team_carousel.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/points_explainer_sheet.dart';
import '../../utils/error_messages.dart';
import '../../utils/firestore_helpers.dart';
import '../../utils/leaderboard_ranks.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (_uid.isEmpty) return;
    // Reminders for the user's upcoming games are rebuilt every time home is
    // entered, which is the only moment the app gets to recalculate them —
    // see EventReminderService.syncFor. openPendingEvent runs afterwards
    // because a reminder tapped from a cold start is only discovered once the
    // service has initialised, and this is the first screen with a navigator
    // to open the event on.
    EventReminderService.syncFor(_uid).then((_) {
      if (mounted) EventReminderService.openPendingEvent();
    });
  }

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

  // Memoised so the hero card's rebuilds reuse one aggregation query instead of
  // issuing a fresh one each time. Keyed on points, the only input the rank
  // depends on, so earning points still refreshes it.
  int? _cityRankPoints;
  Future<int>? _cityRankResult;

  Future<int> _cityRankFuture(int points) {
    if (_cityRankResult == null || _cityRankPoints != points) {
      _cityRankPoints = points;
      _cityRankResult = RankingService.cityRank(points: points);
    }
    return _cityRankResult!;
  }

  // ── Avatar menu ───────────────────────────

  void _showAvatarMenu(BuildContext context,
      String firstName, String lastName, String role, String? photoUrl) {
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
            // Mirrors the header avatar in _buildHeader — this sheet used to
            // render initials unconditionally because it never received the
            // photo URL, so the menu disagreed with the header above it.
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.accent, AppTheme.accent2]),
                borderRadius: BorderRadius.circular(14)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(photoUrl, fit: BoxFit.cover,
                        width: 48, height: 48,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(_initials(firstName, lastName),
                                style: const TextStyle(
                                    color: AppTheme.buttonFg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800))))
                    : Center(child: Text(_initials(firstName, lastName),
                        style: const TextStyle(color: AppTheme.buttonFg,
                            fontSize: 16, fontWeight: FontWeight.w800))),
              ),
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
                color: AppTheme.errorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.errorText.withValues(alpha: 0.4))),
              child: Row(children: [
                Icon(LucideIcons.logOut, color: AppTheme.errorText, size: 20),
                const SizedBox(width: 12),
                Text('Sign Out', style: TextStyle(
                  color: AppTheme.errorText, fontSize: 15,
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
                  // friendlyError rather than the raw exception, which put
                  // strings like "[cloud_firestore/failed-precondition] The
                  // query requires an index…" in front of users.
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(friendlyError(snapshot.error),
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
                    // Every event notification carries its eventId in
                    // relatedId, so the tile can open the event itself.
                    // stats_added is deliberately left out: its relatedId is
                    // a statId, not an event.
                    final relatedId = n.relatedId ?? '';
                    final opensEvent = relatedId.isNotEmpty &&
                        const {
                          NotificationType.eventAdded,
                          NotificationType.eventUpdated,
                          NotificationType.eventCancelled,
                          NotificationType.eventReminder,
                        }.contains(n.type);
                    final opensInvite =
                        n.type == NotificationType.teamInvite;
                    return GestureDetector(
                      onTap: () {
                        Get.back();
                        if (opensEvent) {
                          Get.toNamed('/events/detail',
                              arguments: {'eventId': relatedId});
                        } else if (opensInvite) {
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
                        Icon(_notificationIcon(n.type),
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
                        // Only the tiles that actually go somewhere get the
                        // chevron, so a tap that does nothing never looks
                        // like a broken link.
                        if (opensEvent || opensInvite) ...[
                          const SizedBox(width: 8),
                          Icon(LucideIcons.chevronRight,
                              color: AppTheme.muted, size: 16),
                        ],
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

  /// The tile icon per notification type. Kept as its own function because
  /// the list grew past what a readable inline ternary chain can hold — add
  /// a case here whenever a new NotificationType is introduced.
  IconData _notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.statsAdded:
        return LucideIcons.barChart2;
      case NotificationType.eventAdded:
        return LucideIcons.calendarCheck;
      case NotificationType.eventUpdated:
        return LucideIcons.calendarClock;
      case NotificationType.eventCancelled:
        return LucideIcons.calendarX;
      case NotificationType.teamInvite:
        return LucideIcons.userPlus;
      case NotificationType.teamFull:
        return LucideIcons.userX;
      default:
        return LucideIcons.bell;
    }
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
            .limit(kMaxListQuery)
            .snapshots()
        : role == 'athlete'
            ? FirebaseFirestore.instance
                .collection('events')
                .where('playerUids', arrayContains: _uid)
                .limit(kMaxListQuery)
                .snapshots()
            // Coach. Membership is stored differently for a coach than for an
            // athlete: they sit on teamACoachId/teamBCoachId and are kept out
            // of playerUids on purpose (see eventAudienceUids), so their own
            // games need an OR across the two fields. This used to list every
            // public event in the app instead, which meant a coach's "Upcoming
            // Games" never actually showed the games they were coaching.
            : FirebaseFirestore.instance
                .collection('events')
                .where(Filter.or(
                  Filter('teamACoachId', isEqualTo: _uid),
                  Filter('teamBCoachId', isEqualTo: _uid),
                ))
                .limit(kMaxListQuery)
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
        builder: (context, scrollController) {
          var showHistory = false;
          return StatefulBuilder(
            builder: (context, setState) => Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          showHistory
                              ? 'Game History'
                              : (role == 'organizer'
                                  ? 'Your Events'
                                  : 'Upcoming Games'),
                          style: TextStyle(color: AppTheme.textPrimary,
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    _EventTabToggle(
                      showHistory: showHistory,
                      onChanged: (value) => setState(() => showHistory = value),
                    ),
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
                      var docs = (snapshot.data?.docs ?? []).where((doc) {
                        final ev = doc.data() as Map<String, dynamic>;
                        // Drafts are organizer-only regardless of role; for
                        // non-organizers the server-side query no longer
                        // filters status (see isEventUpcoming's cancelled
                        // handling), so exclude drafts here instead.
                        if (role != 'organizer' && ev['status'] == 'draft') {
                          return false;
                        }
                        return isEventUpcoming(ev) != showHistory;
                      }).toList();
                      docs.sort((a, b) {
                        final aT = asTimestamp((a.data() as Map)['eventDate']);
                        final bT = asTimestamp((b.data() as Map)['eventDate']);
                        if (aT == null || bT == null) return 0;
                        return showHistory
                            ? bT.compareTo(aT)
                            : aT.compareTo(bT);
                      });
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                              showHistory
                                  ? 'No past games yet'
                                  : 'Nothing here yet',
                              style: TextStyle(
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
            );
          },
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
                  .limit(kMaxListQuery)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  // friendlyError rather than the raw exception, which put
                  // strings like "[cloud_firestore/failed-precondition] The
                  // query requires an index…" in front of users.
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(friendlyError(snapshot.error),
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
          Get.toNamed('/events')
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
      case 'My Events':      Get.toNamed('/events');        return;
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
          // This is the first thing shown after the splash, so a spinner on
          // an empty screen reads as a second loading screen. A skeleton
          // shaped like the dashboard makes the handoff feel continuous and
          // stops the layout jumping when the document arrives.
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: const SafeArea(child: HomeSkeleton()),
          );
        }
        final data      = snapshot.data?.data()
            as Map<String, dynamic>? ?? {};
        final role      = data['role']      as String? ?? 'athlete';
        final firstName = data['firstName'] as String? ?? '';
        final lastName  = data['lastName']  as String? ?? '';

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: SafeArea(child: Column(children: [
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
        // No horizontal padding here: the team deck runs to the screen edges
        // so the cards either side of the focused one stay visible. It pads
        // its own header and footer to the 20pt gutter.
        _buildAthleteTeamSection(),
      ],
      // CHANGED: athlete's Features grid duplicated the bottom nav
      // tab-for-tab (Dashboard=Stats, Leaderboard=Rankings, Find
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
        _buildCoachTeamSection(data),
      ] else if (role == 'organizer') ...[
        _buildSectionTitle('Next Event'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildOrganizerNextEventSection(),
        ),
        _buildSectionTitle('Tournaments',
            onViewAll: () => Get.toNamed('/tournaments')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildOrganizerTournamentSection(),
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
        // Say something went wrong instead of silently showing "No stats
        // yet" — but in words a user can read. The raw exception (most often
        // a missing athleteId + createdAt index) belongs in the debug console,
        // not on an athlete's home screen.
        if (snapshot.hasError) {
          return _EmptyCard(
            icon: LucideIcons.alertCircle,
            title: 'Could not load activity',
            subtitle: friendlyError(snapshot.error),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          // Organizers are the only role the rules let write stats — this
          // used to say "coach or organizer". The action is the one thing an
          // athlete can do alone while they wait: give coaches footage.
          return _EmptyCard(
            icon: LucideIcons.barChart2,
            title: 'No stats yet',
            subtitle: 'The organizer adds them after your first game. '
                'Until then, give coaches something to watch.',
            actionLabel: 'Add a highlight',
            onAction: () => Get.toNamed('/profile'),
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
          onTap: () =>
              _showAvatarMenu(context, firstName, lastName, role, photoUrl),
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

    final ranked = points > 0;

    return Column(children: [
      Row(children: [
        // The whole points block opens "How points work": a TOTAL POINTS
        // that isn't the points you scored needs explaining somewhere.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showPointsExplainerSheet(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('TOTAL POINTS', style: TextStyle(color: AppTheme.sub,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(width: 4),
              Icon(LucideIcons.info, color: AppTheme.sub, size: 12),
            ]),
            const SizedBox(height: 4),
            Text('$points', style: const TextStyle(color: AppTheme.accent,
                fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 2),
            Text(ranked
                    ? 'Earn points by playing games'
                    : 'Play a recorded game to get ranked',
                style: TextStyle(color: AppTheme.sub, fontSize: 10)),
          ]),
        ),
        const Spacer(),
        // ── Real city rank ──
        // No query while unranked: the answer would be a tie for first with
        // everyone else on zero, which is exactly what used to be shown.
        FutureBuilder<int>(
          future: ranked ? _cityRankFuture(points) : null,
          builder: (context, snap) {
            final rank = cityRankLabel(points: points, rank: snap.data);
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
                Text(ranked ? 'City Rank' : 'Unranked',
                    style: TextStyle(color: AppTheme.sub, fontSize: 9)),
              ]),
            );
          },
        ),
      ]),
      const SizedBox(height: 12),
      // A Wrap, not a Row: with the recruitment pill spelled out, a long
      // position ("Defensive Specialist") no longer fits one line on a small
      // phone, and a Row would overflow instead of wrapping.
      Wrap(spacing: 6, runSpacing: 6, children: [
        _StatPill(label: position,
            icon: LucideIcons.activity),
        _StatPill(label: years, icon: LucideIcons.clock),
        // Said in full — a bare "Open"/"Closed" left the athlete guessing
        // open to what.
        _StatPill(label: isOpen ? 'Open to recruit' : 'Not recruiting',
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
          Text(level, style: const TextStyle(color: AppTheme.accent,
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
          Text(org, style: const TextStyle(color: AppTheme.accent,
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
            child: const Text('View All', style: TextStyle(
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
            // Only the deck runs full-bleed; the single-card states keep the
            // 20pt gutter every other home section uses.
            if (teams.isNotEmpty) {
              return _buildOnTeamCard(teams, pendingDocs.length);
            }
            // Both streams start out empty, which is indistinguishable from
            // "has no team" — without this an athlete who does have one is
            // shown "No Team Yet" until Firestore answers.
            if (teamsSnap.connectionState == ConnectionState.waiting ||
                pendingSnap.connectionState == ConnectionState.waiting) {
              return const TeamCarouselSkeleton();
            }
            if (pendingDocs.isNotEmpty) {
              final first = TeamInvite.fromMap(pendingDocs.first.id,
                  pendingDocs.first.data() as Map<String, dynamic>);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildInvitedCard(pendingDocs.length, first),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildNoTeamCard(),
            );
          },
        );
      },
    );
  }

  /// The athlete's team as a swipeable deck: their coach first, then every
  /// teammate. Tapping any card expands the deck in place into the full
  /// roster; the footer still routes to the dedicated team screen.
  ///
  /// The teammate count now comes off the same roster stream that feeds the
  /// cards, rather than a separate `rosterCountFor` aggregate — one less read,
  /// and it stays live when someone joins or leaves.
  Widget _buildOnTeamCard(List<TeamInvite> teams, int pendingCount) {
    final team = teams.first;

    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(team.coachId),
      builder: (context, rosterSnap) {
        // The team name is already known here, so the placeholder keeps it and
        // only the deck below is stubbed out.
        if (rosterSnap.connectionState == ConnectionState.waiting) {
          return TeamCarouselSkeleton(title: team.teamName);
        }
        final everyone = (rosterSnap.data?.docs ?? [])
            .map((d) =>
                TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>));
        final self = everyone.where((m) => m.athleteId == _uid).firstOrNull;
        final teammates = everyone.where((m) => m.athleteId != _uid).toList()
          ..sort((a, b) => (b.respondedAt ?? DateTime(0))
              .compareTo(a.respondedAt ?? DateTime(0)));

        return TeamCarouselLoader(
          title: team.teamName,
          countLabel: '${teammates.length} '
              'teammate${teammates.length == 1 ? '' : 's'}',
          seeds: [
            TeamMemberSeed(
              uid: team.coachId,
              fallbackName: team.coachName,
              fallbackSubtitle: 'Head Coach',
              isCoach: true,
            ),
            // Right after the coach: the deck opens centred on the coach, so
            // this is the peek card visible at rest, without swiping — the
            // roster used to leave the viewer out of their own team entirely.
            TeamMemberSeed(
              uid: _uid,
              isSelf: true,
              fallbackName: self?.athleteName ?? 'You',
              fallbackPhotoUrl: self?.athletePhotoUrl,
              fallbackSubtitle: 'You',
            ),
            ...teammates.map((m) => TeamMemberSeed(
                  uid: m.athleteId,
                  fallbackName: m.athleteName,
                  fallbackPhotoUrl: m.athletePhotoUrl,
                  fallbackSubtitle: 'Teammate',
                )),
          ],
          footer: GestureDetector(
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
            behavior: HitTestBehavior.opaque,
            child: const Row(children: [
              Text('View Team', style: TextStyle(
                  color: AppTheme.accent, fontSize: 13,
                  fontWeight: FontWeight.w700)),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.accent, size: 16),
            ]),
          ),
        );
      },
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
              child: const Icon(LucideIcons.userPlus,
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
              // Still about invites, since that is where this card goes, but
              // it names the one thing an athlete can do to earn one.
              Text('Coach invites land here. Highlights on your profile '
                  'help you get noticed.',
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

        // Same trap as the athlete's section: a still-connecting stream looks
        // exactly like an empty roster, so a coach who has players would be
        // told they have none until Firestore answers.
        if (rosterSnap.connectionState == ConnectionState.waiting) {
          return TeamCarouselSkeleton(title: teamName);
        }

        // An empty roster keeps the compact prompt card — a lone "add player"
        // tile floating in a 232pt deck reads as a layout bug, not an invite.
        if (roster.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                Text(teamName, style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Icon(Icons.groups_outlined, color: AppTheme.muted, size: 28),
                const SizedBox(height: 8),
                Text('No athletes on your roster yet', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => Get.toNamed('/scout'),
                  child: const Text('Invite athletes from Scout', style: TextStyle(
                      color: AppTheme.accent, fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          );
        }

        return TeamCarouselLoader(
          title: teamName,
          countLabel: '${roster.length}/${TeamService.maxPlayers}',
          countIsWarning: isFull,
          seeds: roster
              .map((m) => TeamMemberSeed(
                    uid: m.athleteId,
                    fallbackName: m.athleteName,
                    fallbackPhotoUrl: m.athletePhotoUrl,
                  ))
              .toList(),
          // A full roster has nowhere to put another player, so the tile that
          // would only lead to a "team is full" error is dropped instead.
          onAddPlayer: isFull ? null : () => Get.toNamed('/scout'),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: TeamService.streamSentPending(_uid),
                builder: (context, pendingSnap) {
                  final pending = pendingSnap.data?.docs.length ?? 0;
                  if (pending == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                behavior: HitTestBehavior.opaque,
                child: const Row(children: [
                  Text('View Full Roster', style: TextStyle(
                      color: AppTheme.accent, fontSize: 13,
                      fontWeight: FontWeight.w700)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accent, size: 16),
                ]),
              ),
            ],
          ),
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
        final docs = (snapshot.data?.docs ?? [])
            .where((doc) => isEventUpcoming(doc.data() as Map<String, dynamic>))
            .toList()
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
                child: const Text('Create your first event', style: TextStyle(
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
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Roster', style: TextStyle(
                      color: AppTheme.accent, fontSize: 13,
                      fontWeight: FontWeight.w700)),
                  SizedBox(width: 4),
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

  // ── Tournaments section (organizer only) ──
  // A running bracket is the organizer's other live workflow alongside the
  // next event, so it gets the same treatment: the one that matters right
  // now, with a way into the full list.

  Widget _buildOrganizerTournamentSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TournamentService.forOrganizer(_uid).map((s) => s),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              Icon(LucideIcons.trophy, color: AppTheme.muted, size: 28),
              const SizedBox(height: 8),
              Text('No tournaments yet', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => Get.toNamed('/tournaments/create'),
                child: const Text('Draw your first bracket', style: TextStyle(
                    color: AppTheme.accent, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }

        final t = Tournament.fromMap(
            docs.first.id, docs.first.data() as Map<String, dynamic>);
        return GestureDetector(
          onTap: () => Get.toNamed('/tournaments/detail',
              arguments: {'tournamentId': t.id}),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: t.isCompleted ? AppTheme.accent : AppTheme.border)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(t.name, style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15,
                        fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.muted, size: 20),
                  ]),
                  const SizedBox(height: 6),
                  Text('${t.sport} · ${t.entrantCount} teams · ${t.venue}',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  if (t.championTeamName != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppTheme.accent, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${t.championTeamName} — champion',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.accent, fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ],
                ]),
          ),
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
              return const _EmptyCard(
                  icon: LucideIcons.calendar,
                  title: 'No events yet',
                  subtitle: 'Tap + to create your first event');
            }
            final events = snapshot.data!.docs
                .where((doc) =>
                    isEventUpcoming(doc.data() as Map<String, dynamic>))
                .toList()
              ..sort((a, b) {
                final aT = asTimestamp((a.data() as Map)['createdAt']);
                final bT = asTimestamp((b.data() as Map)['createdAt']);
                if (aT == null || bT == null) return 0;
                return bT.compareTo(aT);
              });
            if (events.isEmpty) {
              return const _EmptyCard(
                  icon: LucideIcons.calendar,
                  title: 'No upcoming events',
                  subtitle: 'Past events have moved to History');
            }
            return _EventList(events: events.take(3).toList());
          },
        ),
      );
    }

    // Coach: an OR across teamACoachId/teamBCoachId, mirroring the query in
    // _showAllEventsSheet. Neither query orders in Firestore — sorting happens
    // client-side below — so no composite index is needed for either.
    final stream = role == 'athlete'
        ? FirebaseFirestore.instance.collection('events')
            .where('playerUids', arrayContains: _uid)
            .limit(10).snapshots()
        : FirebaseFirestore.instance.collection('events')
            .where(Filter.or(
              Filter('teamACoachId', isEqualTo: _uid),
              Filter('teamBCoachId', isEqualTo: _uid),
            ))
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
          // Both empty branches below say the same thing. The action points at
          // the Game Directory: being added to a game is up to an organizer,
          // but seeing what is being played nearby is not.
          Widget noUpcomingGames() => _EmptyCard(
              icon: LucideIcons.activity,
              title: role == 'athlete'
                  ? "You're not in any upcoming events"
                  : 'No upcoming games yet',
              subtitle: role == 'athlete'
                  ? 'An organizer will add you to events'
                  // No longer "check back soon": the list is now this coach's
                  // own games, so the thing they are waiting on is an
                  // organizer entering their team into one.
                  : 'Games your team is entered in will appear here',
              actionLabel: 'Browse games near you',
              onAction: () => Get.toNamed('/venues'));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return noUpcomingGames();
          }
          final events = snapshot.data!.docs
              .where((doc) {
                final ev = doc.data() as Map<String, dynamic>;
                return ev['status'] != 'draft' && isEventUpcoming(ev);
              })
              .toList()
            ..sort((a, b) {
            final aT = asTimestamp((a.data() as Map)['eventDate']);
            final bT = asTimestamp((b.data() as Map)['eventDate']);
            if (aT == null || bT == null) return 0;
            return aT.compareTo(bT);
          });
          if (events.isEmpty) return noUpcomingGames();
          return _EventList(events: events.take(3).toList());
        },
      ),
    );
  }

  // ── Bottom nav ────────────────────────────
  // CHANGED: redesigned as a floating pill (margin on all sides,
  // fully rounded), captioned tabs, and a filled circular badge
  // behind the active icon instead of just a color change — matches
  // the modern Android nav pattern you referenced.

  Widget _buildBottomNav(String role) {
    final items = _navItems(role);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
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
        // Each tab takes an equal share so the captions line up under their
        // icons whatever their length ("Add Stats" beside "Home").
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == _navIndex;
            return Expanded(
              child: _BottomNavItem(
                icon: items[i]['icon'] as IconData,
                label: items[i]['label'] as String,
                active: active,
                onTap: () => _onNavTap(i, role),
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
          {'icon': LucideIcons.trophy,   'label': 'Rankings'},
          {'icon': LucideIcons.mapPin,   'label': 'Games'},
          {'icon': LucideIcons.user,     'label': 'Profile'},
        ];
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────

// Adds real press feedback (a quick scale-down/release on tap) and, for
// pointer-driven platforms like the Windows/web builds, a hover tint —
// on top of the existing active-tab color fill, which stays untouched.
//
// Captioned. The labels had always been defined in _navItems but were never
// drawn, so first-time users had to guess what the bar chart and the map pin
// led to, and a screen reader announced five unlabeled buttons.
class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _pressed = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          // Opaque so the caption and the gaps beside it are part of the
          // target, not just the circle.
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.active
                      ? AppTheme.accent
                      : _hovering
                          ? AppTheme.accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.active ? AppTheme.buttonFg : AppTheme.muted,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.active ? AppTheme.accentText : AppTheme.muted,
                  fontSize: 10,
                  fontWeight:
                      widget.active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

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
        // The raw `status` field is only ever 'draft' or 'upcoming' and
        // never updates itself once a game happens, so the displayed
        // label is derived from the real eventDate instead of trusted
        // as-is — see isEventUpcoming() in firestore_helpers.dart.
        final isCancelled = ev['status'] == 'cancelled';
        final isDraft     = ev['status'] == 'draft';
        final isCompleted = !isCancelled && !isDraft && !isEventUpcoming(ev);
        final badgeLabel  = isCancelled ? 'CANCELLED'
            : isDraft ? 'DRAFT' : (isCompleted ? 'COMPLETED' : 'UPCOMING');
        final isNeutral   = isCancelled || isDraft || isCompleted;
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
                color: isNeutral
                    ? AppTheme.cardNested : AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNeutral
                      ? AppTheme.border : AppTheme.accent)),
              child: Text(badgeLabel, style: TextStyle(
                color: isNeutral
                    ? AppTheme.muted : AppTheme.accentText,
                fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }).toList()),
    );
  }
}

/// Segmented Upcoming/History toggle for the "View All Events" sheet.
class _EventTabToggle extends StatelessWidget {
  final bool showHistory;
  final ValueChanged<bool> onChanged;
  const _EventTabToggle({required this.showHistory, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildOption('Upcoming', selected: !showHistory,
            onTap: () => onChanged(false)),
        _buildOption('History', selected: showHistory,
            onTap: () => onChanged(true)),
      ]),
    );
  }

  Widget _buildOption(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(17)),
        child: Text(label, style: TextStyle(
            color: selected ? AppTheme.buttonFg : AppTheme.sub,
            fontSize: 11, fontWeight: FontWeight.w700)),
      ),
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
                  style: const TextStyle(
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

  /// An optional next step. An athlete's first visit is almost all empty
  /// states, and an empty state that only says "wait for someone else" gives
  /// them nothing to do — so the ones they can act on offer a way forward.
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(actionLabel!,
                      style: TextStyle(
                          color: AppTheme.accentText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accentText, size: 16),
                ]),
              ),
            ),
          ],
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