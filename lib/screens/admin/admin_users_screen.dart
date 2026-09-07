// lib/screens/admin/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';
import 'admin_user_detail_screen.dart';

/// Every account on the platform, which the super-admin previously had no way
/// to see at all — the console's only list was the organizer approval queue.
///
/// Unlike Scout and the Leaderboard, this screen deliberately does **not**
/// apply `isListableProfile`. That guard hides tombstoned and nameless
/// profiles from the public surfaces, and this is the one place they still
/// need to be visible: an admin looking for an account that has gone wrong is
/// exactly the person who should see it. They are badged instead of hidden.
///
/// Filtering and search run client-side over a single `users` stream. That is
/// the right trade at this size — Firestore cannot do substring search without
/// a third-party index, and the alternative is a composite index per filter
/// combination for a collection numbering in the dozens.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _role = 'all';

  static const _roles = <String, String>{
    'all': 'All',
    'athlete': 'Athletes',
    'coach': 'Coaches',
    'organizer': 'Organizers',
    'admin': 'Admins',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildTopBar(),
          _buildSearch(),
          const SizedBox(height: 10),
          _buildRoleFilter(),
          const SizedBox(height: 12),
          Expanded(child: _buildList()),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Text('Users',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name',
            hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
            prefixIcon:
                Icon(LucideIcons.search, color: AppTheme.muted, size: 18),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(LucideIcons.x, color: AppTheme.muted, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: AppTheme.inputFill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent)),
          ),
        ),
      );

  Widget _buildRoleFilter() => SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _roles.entries.map((e) {
            final selected = _role == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _role = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          color: selected ? AppTheme.buttonFg : AppTheme.sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _buildList() {
    // No orderBy: sorting server-side on fullName would need an index per
    // role filter, and the list is sorted client-side below anyway.
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('users');
    if (_role != 'all') query = query.where('role', isEqualTo: _role);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(LucideIcons.triangleAlert, "Couldn't load accounts");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
        }

        final users = snapshot.data!.docs.where((doc) {
          if (_query.isEmpty) return true;
          return _displayName(doc.data()).toLowerCase().contains(_query);
        }).toList()
          ..sort((a, b) =>
              _displayName(a.data()).toLowerCase().compareTo(
                  _displayName(b.data()).toLowerCase()));

        if (users.isEmpty) {
          return _message(
              LucideIcons.users,
              _query.isEmpty
                  ? 'No accounts in this role'
                  : 'No accounts match "$_query"');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _userTile(users[i]),
        );
      },
    );
  }

  Widget _userTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final u = doc.data();
    final deleted = u['deleted'] == true;
    final suspended = u['suspended'] == true;
    final photo = asString(u['photoUrl']);

    return GestureDetector(
      onTap: () => Get.to(() => AdminUserDetailScreen(uid: doc.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.cardNested,
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
            child: photo.isEmpty
                ? Icon(LucideIcons.user, color: AppTheme.muted, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName(u),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(children: [
                  Text(_roleLabel(asString(u['role'])),
                      style: TextStyle(color: AppTheme.sub, fontSize: 11.5)),
                  if (asString(u['barangay']).isNotEmpty) ...[
                    Text(' · ',
                        style:
                            TextStyle(color: AppTheme.muted, fontSize: 11.5)),
                    Flexible(
                      child: Text(asString(u['barangay']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: AppTheme.sub, fontSize: 11.5)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          if (deleted)
            statusChip('Deleted', AppTheme.muted)
          else if (suspended)
            statusChip('Suspended', AppTheme.warning),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 16),
        ]),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.muted, size: 40),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        ]),
      );

  static String _roleLabel(String role) =>
      role.isEmpty ? 'No role yet' : '${role[0].toUpperCase()}${role.substring(1)}';
}

/// Falls back through the same name fields `isListableProfile` inspects, then
/// to a placeholder — a tombstoned or half-registered account still has to
/// render as a tappable row here rather than a blank one.
String _displayName(Map<String, dynamic> user) {
  final full = asString(user['fullName']).trim();
  if (full.isNotEmpty) return full;
  final parts =
      '${asString(user['firstName'])} ${asString(user['lastName'])}'.trim();
  return parts.isEmpty ? 'Unnamed account' : parts;
}

/// Shared with the detail screen so a status reads identically in both places.
Widget statusChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );

/// Exposed for the detail screen, which shows the same name for the same
/// account.
String adminDisplayName(Map<String, dynamic> user) => _displayName(user);
