// lib/screens/admin/admin_review_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// The one screen a super-admin account sees, reached only when
/// `users/{uid}.role == 'admin'` — see splash_screen.dart's routing branch.
/// There is deliberately no way to reach this role through the public app;
/// an admin account only ever exists because someone hand-set it directly
/// in Firestore. Its only job is approving/rejecting pending organizer
/// signups (see organizer_register_screen.dart, which writes
/// `organizerStatus: 'pending'`, and firestore.rules, which blocks an
/// unapproved organizer from creating events regardless of this screen).
class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'organizer')
                  .where('organizerStatus', isEqualTo: 'pending')
                  .snapshots(),
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
                      Text('No pending organizer approvals',
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
                    return _PendingOrganizerCard(
                      uid: doc.id,
                      name: u['fullName'] as String? ?? '',
                      email: u['email'] as String? ?? '',
                      organization: u['organization'] as String? ?? '',
                      sportsOrganized:
                          (u['sportsOrganized'] as List?)?.cast<String>() ?? [],
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
}

class _PendingOrganizerCard extends StatelessWidget {
  final String uid;
  final String name;
  final String email;
  final String organization;
  final List<String> sportsOrganized;

  const _PendingOrganizerCard({
    required this.uid,
    required this.name,
    required this.email,
    required this.organization,
    required this.sportsOrganized,
  });

  Future<void> _decide(String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid)
        .update({'organizerStatus': status});
    await NotificationService.create(
      userId: uid,
      type: 'organizer_status',
      title: status == 'approved'
          ? "You're approved!"
          : 'Organizer request declined',
      body: status == 'approved'
          ? 'Your organizer account has been approved — you can now create events.'
          : 'Your organizer account was not approved this time.',
      relatedId: uid,
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
        Text(name.isNotEmpty ? name : 'Unnamed organizer',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(email, style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        if (organization.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(organization,
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ],
        if (sportsOrganized.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sportsOrganized
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
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _decide('rejected'),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text('Reject',
                  style: TextStyle(color: AppTheme.error, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _decide('approved'),
              child: const Text('Approve'),
            ),
          ),
        ]),
      ]),
    );
  }
}
