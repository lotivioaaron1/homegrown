// lib/screens/admin/admin_overview_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../services/admin_stats_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';
import 'admin_tabs.dart';

/// The super-admin's landing tab: what the platform currently holds, and what
/// is waiting on the admin.
///
/// The pending-approvals card at the top exists to solve a real gap rather
/// than to decorate the screen. Organizer registration notifies every admin of
/// a new application, but the notification bell lives on /home, which an admin
/// account never reaches — so before this screen those notifications piled up
/// unread forever. Surfacing the count here, one tap from the queue itself, is
/// what that notification was always trying to achieve.
class AdminOverviewScreen extends StatefulWidget {
  /// Jumps the surrounding shell to another tab by index. Supplied by
  /// AdminShellScreen so the cards on this screen can act as shortcuts.
  final void Function(int tabIndex) onOpenTab;

  const AdminOverviewScreen({super.key, required this.onOpenTab});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  late Future<AdminStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = AdminStatsService.load();
  }

  Future<void> _refresh() async {
    final next = AdminStatsService.load();
    setState(() => _stats = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppTheme.accent,
              backgroundColor: AppTheme.card,
              child: FutureBuilder<AdminStats>(
                future: _stats,
                builder: (context, snapshot) {
                  // A failed aggregation still renders the page skeleton with
                  // zeroes plus an explicit banner, rather than an empty
                  // screen that looks like a platform with no data in it.
                  final stats = snapshot.data ?? const AdminStats.empty();
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final failed = snapshot.hasError;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (failed) ...[
                        _errorBanner(),
                        const SizedBox(height: 14),
                      ],
                      _pendingCard(stats, loading),
                      // Only shown when there is something to act on. A row
                      // of permanent zeroes would train the admin to ignore
                      // this part of the screen.
                      if (stats.openReports > 0) ...[
                        const SizedBox(height: 10),
                        _attentionRow(
                          LucideIcons.flag,
                          AppTheme.error,
                          '${stats.openReports} open '
                              'report${stats.openReports == 1 ? '' : 's'}',
                          AdminTab.reports,
                        ),
                      ],
                      if (stats.suspended > 0) ...[
                        const SizedBox(height: 10),
                        _attentionRow(
                          LucideIcons.userX,
                          AppTheme.warning,
                          '${stats.suspended} suspended '
                              'account${stats.suspended == 1 ? '' : 's'}',
                          AdminTab.users,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _sectionLabel('Community'),
                      const SizedBox(height: 10),
                      _statGrid([
                        _Stat('Total accounts', stats.users, LucideIcons.users),
                        _Stat('Athletes', stats.athletes, LucideIcons.zap),
                        _Stat('Coaches', stats.coaches, LucideIcons.clipboardList),
                        _Stat('Organizers', stats.organizers, LucideIcons.shieldCheck),
                      ], loading),
                      const SizedBox(height: 20),
                      _sectionLabel('Activity'),
                      const SizedBox(height: 10),
                      _statGrid([
                        _Stat('Events', stats.events, LucideIcons.calendar),
                        _Stat('Upcoming', stats.upcomingEvents, LucideIcons.calendarClock),
                        _Stat('Matches recorded', stats.matches, LucideIcons.trophy),
                      ], loading),
                      const SizedBox(height: 20),
                      _sectionLabel('Recent activity'),
                      const SizedBox(height: 10),
                      const _RecentActivity(),
                    ],
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Chrome ────────────────────────────────────────────────

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Superadmin console',
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => AuthController.to.signOut(),
            child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Icon(Icons.logout_rounded,
                    color: AppTheme.textPrimary, size: 16)),
          ),
        ]),
      );

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800));

  Widget _errorBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppTheme.errorSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(LucideIcons.triangleAlert, color: AppTheme.errorText, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text("Couldn't load the latest counts. Pull to retry.",
                style: TextStyle(color: AppTheme.errorText, fontSize: 12)),
          ),
        ]),
      );

  // ── Attention cards ───────────────────────────────────────

  Widget _pendingCard(AdminStats stats, bool loading) {
    final waiting = stats.pendingOrganizers;
    final none = !loading && waiting == 0;

    return GestureDetector(
      onTap: () => widget.onOpenTab(AdminTab.approvals),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: none ? AppTheme.card : AppTheme.accentSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: none
                  ? AppTheme.border
                  : AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: none ? AppTheme.cardNested : AppTheme.accent,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(LucideIcons.userCheck,
                size: 20,
                color: none ? AppTheme.muted : AppTheme.buttonFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    loading
                        ? 'Organizer approvals'
                        : none
                            ? 'No approvals waiting'
                            : '$waiting organizer${waiting == 1 ? '' : 's'} waiting',
                    style: TextStyle(
                        color: none
                            ? AppTheme.textPrimary
                            : AppTheme.accentText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    none
                        ? 'Every application has been reviewed'
                        : 'Review their verification and decide',
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 18),
        ]),
      ),
    );
  }

  /// A one-line "something needs you" row that jumps to the tab holding it.
  /// Shared by open reports and suspended accounts so the two read as one
  /// list rather than two differently-shaped cards.
  Widget _attentionRow(IconData icon, Color tint, String label, int tab) =>
      GestureDetector(
        onTap: () => widget.onOpenTab(tab),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            Icon(icon, color: tint, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 18),
          ]),
        ),
      );

  // ── Stat grid ─────────────────────────────────────────────

  Widget _statGrid(List<_Stat> stats, bool loading) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: stats
                .map((s) => SizedBox(
                    width: width, child: _statTile(s, loading)))
                .toList(),
          );
        },
      );

  Widget _statTile(_Stat stat, bool loading) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stat.icon, color: AppTheme.accent, size: 18),
            const SizedBox(height: 12),
            Text(loading ? '—' : '${stat.value}',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            const SizedBox(height: 4),
            Text(stat.label,
                style: TextStyle(color: AppTheme.sub, fontSize: 11.5)),
          ],
        ),
      );
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
}

/// The admin's own notification feed, which until now had no screen to appear
/// on. Read-only — the rules already let a user read notifications addressed
/// to them, so this needs no new permission.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
            child: Text(
                snapshot.hasError ? 'Activity unavailable' : 'Nothing yet',
                style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          );
        }

        return Container(
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final n = entry.value.data() as Map<String, dynamic>;
              final isLast = entry.key == docs.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: n['read'] == true
                              ? AppTheme.muted
                              : AppTheme.accent,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asString(n['title']),
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          if (asString(n['body']).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(asString(n['body']),
                                style: TextStyle(
                                    color: AppTheme.sub,
                                    fontSize: 12,
                                    height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_relative(asTimestamp(n['createdAt'])?.toDate()),
                        style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static String _relative(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
