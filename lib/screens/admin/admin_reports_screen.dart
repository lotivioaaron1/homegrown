// lib/screens/admin/admin_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import 'admin_user_detail_screen.dart';

/// The queue of user- and event-reports filed from around the app.
///
/// Resolving a report is deliberately not the same act as punishing the person
/// reported. "Resolve" records that the admin dealt with it; suspending an
/// account is a separate, explicit decision made on that account's own screen,
/// reached from the link on a user report. Bundling the two would make it far
/// too easy to suspend someone as a side effect of tidying a list.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildTopBar(),
          const SizedBox(height: 4),
          _buildToggle(),
          const SizedBox(height: 12),
          Expanded(child: _buildList()),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Text('Reports',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  // Same segmented control the approval queue uses, so the two tabs that both
  // hold a work queue behave identically.
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
          seg('Open', !_showClosed, () => setState(() => _showClosed = false)),
          seg('Closed', _showClosed, () => setState(() => _showClosed = true)),
        ]),
      ),
    );
  }

  Widget _buildList() {
    // whereIn on the closed tab so dismissed and resolved share one list —
    // both are "dealt with", and splitting them would mean a third segment
    // for a distinction the admin rarely needs to make after the fact.
    final query = _showClosed
        ? FirebaseFirestore.instance.collection('reports').where('status',
            whereIn: [Report.statusResolved, Report.statusDismissed])
        : FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: Report.statusOpen);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(
              LucideIcons.triangleAlert, "Couldn't load reports");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _message(
              LucideIcons.flag,
              _showClosed
                  ? 'Nothing has been closed yet'
                  : 'No open reports');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ReportCard(
            key: ValueKey(docs[i].id),
            report: Report.fromMap(docs[i].id, docs[i].data()),
          ),
        );
      },
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.muted, size: 40),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        ]),
      );
}

class _ReportCard extends StatefulWidget {
  final Report report;
  const _ReportCard({super.key, required this.report});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final isUser = r.targetType == Report.targetUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isUser ? LucideIcons.user : LucideIcons.calendar,
                    size: 11, color: AppTheme.sub),
                const SizedBox(width: 5),
                Text(isUser ? 'Account' : 'Event',
                    style: TextStyle(
                        color: AppTheme.sub,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const Spacer(),
            if (!r.isOpen)
              Text(
                  r.status == Report.statusResolved ? 'Resolved' : 'Dismissed',
                  style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            if (r.isOpen)
              Text(_relative(r.createdAt),
                  style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Text(r.targetLabel.isEmpty ? 'Unnamed target' : r.targetLabel,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(r.reason,
              style: TextStyle(
                  color: AppTheme.errorText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          if (r.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(r.details,
                  style: TextStyle(
                      color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
            ),
          ],
          const SizedBox(height: 10),
          Text(
              'Reported by ${r.reporterName.isEmpty ? 'an unnamed account' : r.reporterName}',
              style: TextStyle(color: AppTheme.muted, fontSize: 11.5)),
          if (isUser) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () =>
                  Get.to(() => AdminUserDetailScreen(uid: r.targetId)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.arrowRight,
                    size: 13, color: AppTheme.accent),
                SizedBox(width: 6),
                Text('Open this account',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          if (r.isOpen) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _button('Dismiss', AppTheme.cardNested, AppTheme.sub,
                    () => _close(ReportService.dismiss(r.id), 'Dismissed')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _button('Resolve', AppTheme.accent, AppTheme.buttonFg,
                    () => _close(ReportService.resolve(r.id), 'Resolved')),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _button(String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: _busy ? AppTheme.cardNested : bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.border)),
          child: Text(label,
              style: TextStyle(
                  color: _busy ? AppTheme.muted : fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ),
      );

  Future<void> _close(Future<void> action, String done) async {
    setState(() => _busy = true);
    try {
      await action;
      // No success snackbar: the card leaves the Open list the moment the
      // write lands, which says the same thing without a second UI element.
    } catch (_) {
      if (mounted) {
        Get.snackbar('Something went wrong',
            "That didn't save. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _relative(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
