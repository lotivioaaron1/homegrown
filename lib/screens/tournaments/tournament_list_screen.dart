// lib/screens/tournaments/tournament_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/tournament.dart';
import '../../services/tournament_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

const _kRadius = 16.0;

/// The organizer's own tournaments, newest first.
class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textPrimary, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text('Tournaments',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed('/tournaments/create'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.accentSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent)),
                  child: Row(children: [
                    Icon(Icons.add_rounded,
                        color: AppTheme.accentText, size: 15),
                    const SizedBox(width: 4),
                    Text('New',
                        style: TextStyle(
                            color: AppTheme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: TournamentService.forOrganizer(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2.5));
                }
                if (snapshot.hasError) {
                  return _empty(
                    icon: Icons.error_outline,
                    title: 'Something went wrong',
                    subtitle: friendlyError(snapshot.error),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _empty(
                    icon: Icons.emoji_events_outlined,
                    title: 'No tournaments yet',
                    subtitle:
                        'Draw a bracket to run several teams down to one champion.',
                    actionLabel: 'New Tournament',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(
                      Tournament.fromMap(docs[i].id, docs[i].data())),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(Tournament t) {
    return GestureDetector(
      onTap: () => Get.toNamed('/tournaments/detail',
          arguments: {'tournamentId': t.id}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(
                color: t.isCompleted ? AppTheme.accent : AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            _statusPill(t),
          ]),
          const SizedBox(height: 6),
          Text(
              '${t.sport} · ${t.entrantCount} teams · ${t.venue}'
              '${t.createdAt == null ? '' : ' · ${DateFormat('MMM d, y').format(t.createdAt!)}'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          if (t.championTeamName != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.championTeamName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _statusPill(Tournament t) {
    final label = t.isCompleted
        ? 'COMPLETE'
        : t.isCancelled
            ? 'CANCELLED'
            : 'IN PROGRESS';
    final highlight = t.isCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: highlight ? AppTheme.accentSurface : AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: highlight ? AppTheme.accent : AppTheme.border)),
      child: Text(label,
          style: TextStyle(
              color: highlight ? AppTheme.accentText : AppTheme.sub,
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.muted, size: 40),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Get.toNamed('/tournaments/create'),
                child: Text(actionLabel),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
