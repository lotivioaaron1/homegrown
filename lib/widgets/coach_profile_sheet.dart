// lib/widgets/coach_profile_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

/// Shared read-only coach profile bottom sheet — avatar, coaching level,
/// experience, org, sports, certifications and bio.
///
/// The counterpart to [showAthleteProfileSheet]: this lived privately inside
/// AthleteTeamScreen until the home screen's team carousel needed the same
/// sheet, at which point copying it would have made a second divergent
/// version of the same UI.
///
/// Pass [coach] when the caller already holds the user doc (the carousel
/// hydrates the whole team in one query), and the sheet skips the fetch.
/// Otherwise it reads `users/{coachId}` itself. [fallbackName] covers the
/// window before the doc lands, or a doc missing `fullName`.
void showCoachProfileSheet(
  BuildContext context, {
  required String coachId,
  Map<String, dynamic>? coach,
  String fallbackName = '',
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) {
        if (coach != null) {
          return _CoachProfileContent(
              scrollController: ctrl,
              coach: coach,
              fallbackName: fallbackName);
        }
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('users').doc(coachId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
            }
            return _CoachProfileContent(
              scrollController: ctrl,
              coach: snapshot.data!.data() as Map<String, dynamic>? ?? {},
              fallbackName: fallbackName,
            );
          },
        );
      },
    ),
  );
}

class _CoachProfileContent extends StatelessWidget {
  final ScrollController scrollController;
  final Map<String, dynamic> coach;
  final String fallbackName;

  const _CoachProfileContent({
    required this.scrollController,
    required this.coach,
    required this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    final name = coach['fullName'] as String? ?? fallbackName;
    final level = coach['coachingLevel'] as String? ?? '—';
    final years = coach['yearsOfExperience'] as String? ?? '—';
    final org = coach['teamOrganization'] as String? ?? '—';
    final barangay = coach['barangay'] as String? ?? '—';
    final certifications = (coach['certifications'] as String? ?? '').trim();
    final bio = (coach['coachingBio'] as String? ?? '').trim();
    final sports =
        (coach['primarySports'] as List?)?.map((e) => e.toString()).join(', ') ??
            '—';
    final photoUrl = coach['photoUrl'] as String?;
    final initials = name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Center(
              child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 2.5)),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(photoUrl,
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: AppTheme.buttonFg,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900))))
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: AppTheme.buttonFg,
                                fontSize: 22,
                                fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 10),
            Text(name,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('$level Coach · $barangay',
                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          ])),
          const SizedBox(height: 20),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          _InfoRow(label: 'Coaching Level', value: level),
          const SizedBox(height: 8),
          _InfoRow(label: 'Experience', value: years),
          const SizedBox(height: 8),
          _InfoRow(label: 'Team / Org', value: org),
          const SizedBox(height: 8),
          _InfoRow(label: 'Sport(s)', value: sports),
          if (certifications.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Certifications',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Text(certifications,
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 13, height: 1.5))),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Bio',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Text(bio,
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 13, height: 1.5))),
          ],
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: Text('Close',
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: AppTheme.muted, fontSize: 12))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
      ]);
}
