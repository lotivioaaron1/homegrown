// lib/screens/admin/admin_review_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../services/contact_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

/// The one screen a super-admin account sees, reached only when
/// `users/{uid}.role == 'admin'` — see splash_screen.dart's routing branch.
/// There is deliberately no way to reach this role through the public app;
/// an admin account only ever exists because someone hand-set it directly
/// in Firestore. Its only job is approving/rejecting pending organizer
/// signups, and revisiting an already-approved one if it turns out to be
/// wrong (see organizer_register_screen.dart, which writes
/// `organizerStatus: 'pending'`, and firestore.rules, which blocks any
/// organizer whose status isn't exactly 'approved' from creating events
/// regardless of this screen).
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  /// 'pending' | 'approved' | 'declined', where 'declined' covers both
  /// 'rejected' and 'revoked'. Was a bool over pending/approved, which meant a
  /// rejected or revoked organizer matched neither filter and disappeared from
  /// this screen for good — with no way to reinstate someone turned down by
  /// mistake, despite that being the whole reason the revoke path exists.
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          const SizedBox(height: 12),
          _buildToggle(),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_user_outlined,
                          color: AppTheme.muted, size: 40),
                      const SizedBox(height: 12),
                      Text(_emptyMessage(),
                          style: TextStyle(
                              color: AppTheme.sub, fontSize: 13)),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final u = doc.data() as Map<String, dynamic>;
                    return _OrganizerCard(
                      // Keyed so the per-card contact fetch survives an
                      // unrelated snapshot tick instead of restarting.
                      key: ValueKey(doc.id),
                      uid: doc.id,
                      name: u['fullName'] as String? ?? '',
                      // Contact details now live in users/{uid}/private and are
                      // fetched by the card. The whole profile map is handed
                      // over so ContactService can fall back to the old
                      // top-level fields for organizers who registered before
                      // the split — see ContactService.read.
                      legacyProfile: u,
                      organization: u['organization'] as String? ?? '',
                      sportsOrganized:
                          (u['sportsOrganized'] as List?)?.cast<String>() ?? [],
                      // The document's own status, not the selected filter —
                      // the Declined tab holds both 'rejected' and 'revoked',
                      // so the tab alone can't tell the card which it is.
                      status: u['organizerStatus'] as String? ?? 'pending',
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

  /// 'declined' fans out to the two statuses a turned-down organizer can
  /// hold. They share a tab because the distinction — never approved versus
  /// approved and later revoked — matters when making the decision, not when
  /// looking back at it.
  Query<Map<String, dynamic>> _query() {
    final organizers = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'organizer');
    return _status == 'declined'
        ? organizers
            .where('organizerStatus', whereIn: ['rejected', 'revoked'])
        : organizers.where('organizerStatus', isEqualTo: _status);
  }

  String _emptyMessage() {
    switch (_status) {
      case 'approved':
        return 'No approved organizers yet';
      case 'declined':
        return 'No declined organizers';
      default:
        return 'No pending organizer approvals';
    }
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Text('Organizer Approvals',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
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

  Widget _buildToggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: selected ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(17)),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? AppTheme.buttonFg : AppTheme.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          seg('Pending', _status == 'pending',
              () => setState(() => _status = 'pending')),
          seg('Approved', _status == 'approved',
              () => setState(() => _status = 'approved')),
          seg('Declined', _status == 'declined',
              () => setState(() => _status = 'declined')),
        ]),
      ),
    );
  }
}

class _OrganizerCard extends StatefulWidget {
  final String uid;
  final String name;
  final Map<String, dynamic> legacyProfile;
  final String organization;
  final List<String> sportsOrganized;

  /// This organizer's own `organizerStatus`: 'pending', 'approved',
  /// 'rejected' or 'revoked'. Decides which actions the card offers.
  final String status;

  const _OrganizerCard({
    super.key,
    required this.uid,
    required this.name,
    required this.legacyProfile,
    required this.organization,
    required this.sportsOrganized,
    required this.status,
  });

  @override
  State<_OrganizerCard> createState() => _OrganizerCardState();
}

class _OrganizerCardState extends State<_OrganizerCard> {
  /// Held in state rather than built in `build` so the read happens once per
  /// card, not on every tick of the enclosing users snapshot.
  late final Future<ContactDetails> _contact = ContactService.read(
    widget.uid,
    legacyProfile: widget.legacyProfile,
  );

  String get uid => widget.uid;

  /// Guards the two awaits below. Without it a failed write was silent — the
  /// card simply stayed put with no explanation — and the buttons remained
  /// live throughout, so a decision could be submitted twice.
  bool _busy = false;

  Future<void> _decide(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _write(status);
    } catch (_) {
      if (mounted) {
        Get.snackbar('Something went wrong',
            "That decision didn't save. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _write(String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid)
        .update({'organizerStatus': status});
    await NotificationService.create(
      userId: uid,
      type: 'organizer_status',
      title: status == 'approved'
          ? "You're approved!"
          : status == 'revoked'
              ? 'Organizer access revoked'
              : 'Organizer request declined',
      body: status == 'approved'
          ? 'Your organizer account has been approved — you can now create events.'
          : status == 'revoked'
              ? 'Your organizer access has been revoked. Contact the app admin for details.'
              : 'Your organizer account was not approved this time.',
      relatedId: uid,
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Revoke this organizer?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
            "They won't be able to create new events. Events they've "
            "already created are unaffected.",
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Back', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _decide('revoked');
            },
            child: const Text('Revoke', style: TextStyle(
                color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name.isNotEmpty ? widget.name : 'Unnamed organizer',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        FutureBuilder<ContactDetails>(
          future: _contact,
          builder: (context, snap) {
            // Reserve the email line's height while loading so approving a
            // queue of organizers doesn't make the cards jump as each
            // resolves.
            final contact = snap.data;
            if (contact == null) {
              return Text(
                  snap.hasError ? 'Contact details unavailable' : '…',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12));
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.email,
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                  if (contact.phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.phone_outlined, color: AppTheme.sub, size: 12),
                      const SizedBox(width: 4),
                      Text(contact.phoneNumber,
                          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                    ]),
                  ],
                ]);
          },
        ),
        if (widget.organization.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.organization,
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ],
        if (widget.sportsOrganized.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.sportsOrganized
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppTheme.cardNested,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border)),
                      child: Text(s,
                          style: TextStyle(
                              color: AppTheme.sub, fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 10),
        _VerificationDoc(uid: uid),
        const SizedBox(height: 12),
        if (widget.status == 'approved')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : () => _confirmRevoke(context),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Revoke',
                  style: TextStyle(color: AppTheme.error, fontSize: 13)),
            ),
          )
        // Already turned down, so there is nothing left to reject. What this
        // card exists for is the way back: approving from here is how a
        // decision made in error gets undone.
        else if (widget.status == 'rejected' || widget.status == 'revoked')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _decide('approved'),
              child: Text(widget.status == 'revoked'
                  ? 'Restore access'
                  : 'Approve after all'),
            ),
          )
        else
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _decide('rejected'),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Reject',
                    style: TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : () => _decide('approved'),
                child: const Text('Approve'),
              ),
            ),
          ]),
      ]),
    );
  }
}

/// Fetches and shows the organizer's optional verification photo, or a
/// clear "no document attached" flag — the whole point of this screen
/// existing is giving the admin a real signal to weigh, not just a name.
class _VerificationDoc extends StatelessWidget {
  final String uid;
  const _VerificationDoc({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: StorageService.fetchOrganizerVerificationDoc(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 24,
              child: Center(child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2))));
        }
        if (snapshot.hasError) {
          // Deliberately NOT the same message as "nothing was ever
          // uploaded" — this is a real failure (e.g. a permission error on
          // the read itself) and needs to look different so it doesn't get
          // misread as "this organizer skipped the photo."
          return Row(children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text("Couldn't load photo: ${snapshot.error}",
                style: const TextStyle(color: AppTheme.error, fontSize: 11))),
          ]);
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.error, size: 14),
            SizedBox(width: 6),
            Text('No verification photo attached',
                style: TextStyle(color: AppTheme.error, fontSize: 11)),
          ]);
        }
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes, height: 120, width: double.infinity,
                fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
