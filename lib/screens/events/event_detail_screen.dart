// lib/screens/events/event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key});

  String get _eventId => (Get.arguments as Map?)?['eventId'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(_eventId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Column(children: [
                _buildTopBar('Event'),
                Expanded(child: Center(child: Text('Event not found',
                    style: TextStyle(color: AppTheme.sub)))),
              ]);
            }
            return _buildContent(
                snapshot.data!.data() as Map<String, dynamic>);
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _buildContent(Map<String, dynamic> ev) {
    final name = ev['name'] as String? ?? 'Untitled Event';
    final status = ev['status'] as String? ?? 'upcoming';
    final sport = ev['sport'] as String? ?? '—';
    final venue = ev['venue'] as String? ?? '—';
    final venueAddress = ev['venueAddress'] as String? ?? '';
    final date = asTimestamp(ev['eventDate']);
    final fmtDate = date != null
        ? DateFormat('EEEE, MMM dd · h:mm a').format(date.toDate())
        : 'Date TBD';
    final playerCount = ev['playerCount'] as int? ?? 0;
    // 'No limit' events are created with maxPlayers left null.
    final maxPlayers = ev['maxPlayers'] as int?;
    final countLabel =
        maxPlayers != null ? '$playerCount/$maxPlayers' : '$playerCount';
    final players = (ev['players'] as List?)
        ?.map((p) => p as Map<String, dynamic>).toList() ?? [];
    final organizerId = ev['organizerId'] as String?;
    final isOrganizer = organizerId != null &&
        organizerId == FirebaseAuth.instance.currentUser?.uid;

    return Column(children: [
      _buildTopBar(name),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: status == 'draft'
                            ? AppTheme.cardNested
                            : AppTheme.accentSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: status == 'draft'
                                ? AppTheme.border
                                : AppTheme.accent)),
                    child: Text(status.toUpperCase(), style: TextStyle(
                        color: status == 'draft'
                            ? AppTheme.muted
                            : AppTheme.accentText,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppTheme.cardNested,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border)),
                    child: Text(countLabel, style: TextStyle(
                        color: AppTheme.sub, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.sports_basketball_outlined, label: sport),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.location_on_outlined,
                    label: venueAddress.isNotEmpty
                        ? '$venue · $venueAddress' : venue),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.calendar_today_outlined, label: fmtDate),
              ]),
            ),
            const SizedBox(height: 20),
            Text('ROSTER', style: TextStyle(
                color: AppTheme.muted, fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            if (players.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(children: [
                  Icon(Icons.groups_outlined, color: AppTheme.muted, size: 28),
                  const SizedBox(height: 8),
                  Text('No players added yet',
                      style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                ]),
              )
            else
              Container(
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: Column(children: players.asMap().entries.map((e) {
                  final isLast = e.key == players.length - 1;
                  final p = e.value;
                  final fullName = p['fullName'] as String? ?? '';
                  final position = p['position'] as String? ?? '';
                  final initials = fullName.trim().split(' ')
                      .where((s) => s.isNotEmpty).take(2)
                      .map((s) => s[0]).join().toUpperCase();
                  return Container(
                    decoration: BoxDecoration(border: Border(
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(color: AppTheme.border))),
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.accent, AppTheme.accent2]),
                          shape: BoxShape.circle),
                        child: Center(child: Text(initials, style: const TextStyle(
                            color: AppTheme.buttonFg, fontSize: 12,
                            fontWeight: FontWeight.w800))),
                      ),
                      title: Text(fullName, style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      subtitle: position.isNotEmpty
                          ? Text(position,
                              style: TextStyle(color: AppTheme.sub, fontSize: 11))
                          : null,
                    ),
                  );
                }).toList()),
              ),
            if (isOrganizer) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed('/matches/record'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Record Match Results', style: TextStyle(
                      color: AppTheme.buttonFg, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.muted, size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(
        color: AppTheme.sub, fontSize: 13), overflow: TextOverflow.ellipsis)),
  ]);
}
