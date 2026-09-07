// lib/screens/admin/admin_user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/admin_user_service.dart';
import '../../services/contact_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';
import 'admin_users_screen.dart';

/// One account, in full, with the two controls the super-admin actually has
/// over it.
///
/// Contact details are fetched through [ContactService], the same call the
/// approval queue makes — email and phone live in `users/{uid}/private/contact`
/// precisely so they are not readable by the whole signed-in population, and
/// the admin is the one account the rules let read someone else's.
class AdminUserDetailScreen extends StatefulWidget {
  final String uid;

  const AdminUserDetailScreen({super.key, required this.uid});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  ContactDetails? _contact;
  bool _contactFailed = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
            }
            final user = snapshot.data?.data();
            if (user == null) {
              return Column(children: [
                _topBar('Account'),
                Expanded(
                  child: Center(
                    child: Text('This account no longer exists',
                        style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                  ),
                ),
              ]);
            }

            // Kicked off once the profile arrives, because the legacy fallback
            // in ContactService needs the profile map to read from.
            _loadContactOnce(user);

            return Column(children: [
              _topBar(adminDisplayName(user)),
              Expanded(child: _body(user)),
            ]);
          },
        ),
      ),
    );
  }

  // ── Chrome ────────────────────────────────────────────────

  Widget _topBar(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  // ── Body ──────────────────────────────────────────────────

  Widget _body(Map<String, dynamic> user) {
    final deleted = user['deleted'] == true;
    final suspended = user['suspended'] == true;
    final role = asString(user['role']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _header(user, deleted, suspended),
        const SizedBox(height: 18),
        if (suspended) ...[
          _suspensionNotice(user),
          const SizedBox(height: 14),
        ],
        _section('Contact', [
          _row(LucideIcons.mail, 'Email', _contactValue((c) => c.email)),
          _row(LucideIcons.phone, 'Phone', _contactValue((c) => c.phoneNumber)),
        ]),
        const SizedBox(height: 14),
        _section('Profile', [
          _row(LucideIcons.shieldCheck, 'Role',
              role.isEmpty ? 'Not set' : role),
          _row(LucideIcons.mapPin, 'Barangay', asString(user['barangay'])),
          if (role == 'athlete' || role == 'coach')
            _row(LucideIcons.zap, 'Sports',
                (user['primarySports'] as List?)?.join(', ') ?? ''),
          if (role == 'organizer') ...[
            _row(LucideIcons.building2, 'Organization',
                asString(user['organization'])),
            _row(LucideIcons.userCheck, 'Approval',
                asString(user['organizerStatus'])),
          ],
          if (role == 'coach')
            _row(LucideIcons.users, 'Team',
                asString(user['teamOrganization'])),
          _row(LucideIcons.calendar, 'Joined',
              _date(asTimestamp(user['createdAt'])?.toDate())),
        ]),
        const SizedBox(height: 20),
        if (deleted)
          _note('This account has been deleted. Its profile is a tombstone — '
              'there is nothing left to suspend.')
        else if (role == 'admin')
          _note('Administrator accounts are not suspendable from here. '
              'An admin who could be locked out would have no way back into '
              'this console, since lifting a suspension happens on this very '
              'screen.')
        else
          _actionButton(suspended),
      ],
    );
  }

  Widget _header(Map<String, dynamic> user, bool deleted, bool suspended) {
    final photo = asString(user['photoUrl']);
    return Row(children: [
      CircleAvatar(
        radius: 30,
        backgroundColor: AppTheme.cardNested,
        backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
        child: photo.isEmpty
            ? Icon(LucideIcons.user, color: AppTheme.muted, size: 26)
            : null,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(adminDisplayName(user),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (deleted)
              statusChip('Deleted', AppTheme.muted)
            else if (suspended)
              statusChip('Suspended', AppTheme.warning)
            else
              statusChip('Active', AppTheme.success),
          ],
        ),
      ),
    ]);
  }

  Widget _suspensionNotice(Map<String, dynamic> user) {
    final reason = asString(user['suspendedReason']).trim();
    final at = asTimestamp(user['suspendedAt'])?.toDate();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.warning.withValues(alpha: 0.35))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.ban, color: AppTheme.warning, size: 15),
            const SizedBox(width: 8),
            Text(at == null ? 'Suspended' : 'Suspended ${_date(at)}',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ]),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reason,
                style: TextStyle(
                    color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: rows),
          ),
        ],
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Icon(icon, color: AppTheme.muted, size: 15),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppTheme.sub, fontSize: 12.5)),
          const Spacer(),
          Flexible(
            child: Text(value.trim().isEmpty ? '—' : value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Text(text,
            style:
                TextStyle(color: AppTheme.sub, fontSize: 12.5, height: 1.55)),
      );

  Widget _actionButton(bool suspended) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy
              ? null
              : () => suspended ? _reinstate() : _promptSuspend(),
          icon: _busy
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.buttonFg))
              : Icon(suspended ? LucideIcons.undo2 : LucideIcons.ban, size: 17),
          label: Text(suspended ? 'Reinstate account' : 'Suspend account',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: suspended ? AppTheme.success : AppTheme.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.cardNested,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  // ── Actions ───────────────────────────────────────────────

  Future<void> _promptSuspend() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Suspend this account?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'They will be held on a notice screen instead of the app until '
                'this is lifted. Their events, stats and team memberships are '
                'left untouched.',
                style: TextStyle(
                    color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 160,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reason (shown to them)',
                hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.inputFill,
                counterStyle: TextStyle(color: AppTheme.muted, fontSize: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspend',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    final reason = controller.text;
    controller.dispose();
    if (confirmed != true) return;

    await _run(
      () => AdminUserService.suspend(widget.uid, reason),
      success: 'Account suspended',
    );
  }

  Future<void> _reinstate() => _run(
        () => AdminUserService.reinstate(widget.uid),
        success: 'Account reinstated',
      );

  /// Wraps both writes in the loading state and error reporting the approval
  /// queue's `_decide` never had — a failed write there was silent, and the
  /// buttons stayed live throughout.
  Future<void> _run(Future<void> Function() action,
      {required String success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Get.snackbar('Done', success);
    } catch (_) {
      if (mounted) {
        Get.snackbar('Something went wrong',
            "That change didn't save. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Contact ───────────────────────────────────────────────

  bool _contactRequested = false;

  void _loadContactOnce(Map<String, dynamic> profile) {
    if (_contactRequested) return;
    _contactRequested = true;
    ContactService.read(widget.uid, legacyProfile: profile).then((c) {
      if (mounted) setState(() => _contact = c);
    }).catchError((_) {
      if (mounted) setState(() => _contactFailed = true);
    });
  }

  String _contactValue(String Function(ContactDetails) pick) {
    if (_contactFailed) return 'Unavailable';
    if (_contact == null) return 'Loading…';
    return pick(_contact!);
  }

  static String _date(DateTime? at) {
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[at.month - 1]} ${at.day}, ${at.year}';
  }
}
