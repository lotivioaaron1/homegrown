// lib/screens/admin/admin_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import 'admin_content_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_review_screen.dart';
import 'admin_tabs.dart';
import 'admin_users_screen.dart';

/// What a super-admin account lands on, replacing the single organizer-approval
/// screen that `/admin` used to point straight at.
///
/// The old screen was a dead end: an admin arrived via `Get.offAllNamed` and
/// had no navigation to anywhere else in the app, which capped the role at the
/// one job that screen did. This shell is the navigation, and
/// [AdminReviewScreen] is hosted inside it completely unchanged — it is
/// rendered as its own `Scaffold` within this one, which Flutter supports and
/// which means the tab that already worked keeps working exactly as before.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = AdminTab.overview;

  void _openTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // IndexedStack rather than swapping the child: each tab keeps its scroll
    // position and its live Firestore listeners across a switch, so moving
    // between the queue and the directory doesn't re-fetch everything.
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: _index,
        children: [
          AdminOverviewScreen(onOpenTab: _openTab),
          const AdminUsersScreen(),
          const AdminContentScreen(),
          const AdminReportsScreen(),
          const AdminReviewScreen(),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  // Deliberately a copy of the floating pill on HomeScreen rather than a
  // widget extracted out of it: that file is long and working, and matching
  // its look costs far less risk here than refactoring it would.
  Widget _buildNav() {
    const items = <IconData>[
      LucideIcons.layoutDashboard, // Overview
      LucideIcons.users,           // Users
      LucideIcons.calendar,        // Content
      LucideIcons.flag,            // Reports
      LucideIcons.userCheck,       // Approvals
    ];
    assert(items.length == AdminTab.count);

    return SafeArea(
      top: false,
      child: Padding(
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
            children: List.generate(
              items.length,
              (i) => _NavItem(
                icon: items[i],
                active: i == _index,
                onTap: () => _openTab(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
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
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

