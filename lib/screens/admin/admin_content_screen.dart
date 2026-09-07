// lib/screens/admin/admin_content_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';

/// Events and tournaments, with the one moderation action the super-admin has
/// over them: cancelling.
///
/// Cancelling rather than deleting, on purpose. `'cancelled'` is a status the
/// app already renders on every surface that shows an event, the organizer
/// already receives an `event_cancelled` notification for it, and anything
/// already recorded — match results, stats, rating history — stays attached to
/// a document that still exists. A delete would strand all of that, and the
/// rules block it anyway once any result has been recorded.
class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  bool _showTournaments = false;

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
          Expanded(
            child:
                _showTournaments ? _buildTournaments() : _buildEvents(),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Text('Content',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
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
          seg('Events', !_showTournaments,
              () => setState(() => _showTournaments = false)),
          seg('Tournaments', _showTournaments,
              () => setState(() => _showTournaments = true)),
        ]),
      ),
    );
  }

  // ── Events ────────────────────────────────────────────────

  Widget _buildEvents() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // No orderBy: ordering by eventDate alongside no filter needs no index,
      // but sorting client-side keeps cancelled events grouped at the bottom
      // where they belong, which a server-side sort cannot express.
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(LucideIcons.triangleAlert, "Couldn't load events");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aCancelled = a.data()['status'] == 'cancelled';
            final bCancelled = b.data()['status'] == 'cancelled';
            if (aCancelled != bCancelled) return aCancelled ? 1 : -1;
            final aDate = asTimestamp(a.data()['eventDate'])?.toDate();
            final bDate = asTimestamp(b.data()['eventDate'])?.toDate();
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return _message(LucideIcons.calendar, 'No events yet');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final ev = docs[i].data();
            final date = asTimestamp(ev['eventDate'])?.toDate();
            return _contentCard(
              icon: LucideIcons.calendar,
              title: asString(ev['name']).isEmpty
                  ? 'Untitled event'
                  : asString(ev['name']),
              subtitle: [
                asString(ev['sport']),
                asString(ev['venue']),
                if (date != null) DateFormat('MMM d, y').format(date),
              ].where((s) => s.isNotEmpty).join(' · '),
              cancelled: ev['status'] == 'cancelled',
              // A bracket matchup belongs to its tournament: cancelling it on
              // its own would leave that slot pointing at a dead event with
              // the bracket unable to advance. Cancel the tournament instead.
              lockedReason: ev['tournamentId'] != null
                  ? 'Part of a tournament bracket'
                  : null,
              onCancel: () => _cancelEvent(
                  docs[i].id, asString(ev['name']), asString(ev['organizerId'])),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelEvent(
      String eventId, String name, String organizerId) async {
    final confirmed = await _confirm(
      'Cancel this event?',
      'It stays visible everywhere as cancelled, and any results already '
          'recorded against it are kept. The organizer is notified.',
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({'status': 'cancelled'});

      // The same notification type the organizer's own cancel flow sends, so
      // a participant sees no difference in how the news reaches them.
      if (organizerId.isNotEmpty) {
        await NotificationService.create(
          userId: organizerId,
          type: 'event_cancelled',
          title: 'Event cancelled by an administrator',
          body: name.isEmpty
              ? 'One of your events has been cancelled.'
              : '"$name" has been cancelled.',
          relatedId: eventId,
        );
      }
    } catch (_) {
      _reportFailure();
    }
  }

  // ── Tournaments ───────────────────────────────────────────

  Widget _buildTournaments() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(
              LucideIcons.triangleAlert, "Couldn't load tournaments");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _message(LucideIcons.trophy, 'No tournaments yet');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = docs[i].data();
            final entrants = (t['entrants'] as List?)?.length ?? 0;
            return _contentCard(
              icon: LucideIcons.trophy,
              title: asString(t['name']).isEmpty
                  ? 'Untitled tournament'
                  : asString(t['name']),
              subtitle: [
                asString(t['sport']),
                '$entrants entrant${entrants == 1 ? '' : 's'}',
                asString(t['status']),
              ].where((s) => s.isNotEmpty).join(' · '),
              cancelled: t['status'] == 'cancelled',
              lockedReason: t['status'] == 'completed'
                  ? 'Already completed'
                  : null,
              onCancel: () => _cancelTournament(docs[i].id),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelTournament(String tournamentId) async {
    final confirmed = await _confirm(
      'Cancel this tournament?',
      'The bracket and every result already played are kept as they are — '
          'the tournament is simply marked cancelled.',
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .update({'status': 'cancelled'});
    } catch (_) {
      _reportFailure();
    }
  }

  // ── Shared pieces ─────────────────────────────────────────

  Widget _contentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool cancelled,
    required String? lockedReason,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppTheme.cardNested,
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: AppTheme.muted, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: cancelled
                          ? AppTheme.muted
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration:
                          cancelled ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.sub, fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (cancelled)
          Text('Cancelled',
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800))
        else if (lockedReason != null)
          Tooltip(
            message: lockedReason,
            child: Icon(LucideIcons.lock, color: AppTheme.muted, size: 15),
          )
        else
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                  color: AppTheme.errorSurface,
                  borderRadius: BorderRadius.circular(9)),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.errorText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          content: Text(message,
              style: TextStyle(
                  color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep it', style: TextStyle(color: AppTheme.sub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel it',
                  style: TextStyle(
                      color: AppTheme.error, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  void _reportFailure() {
    if (!mounted) return;
    Get.snackbar('Something went wrong',
        "That didn't save. Check your connection and try again.");
  }

  Widget _loading() => const Center(
      child: CircularProgressIndicator(
          color: AppTheme.accent, strokeWidth: 2));

  Widget _message(IconData icon, String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.muted, size: 40),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        ]),
      );
}
