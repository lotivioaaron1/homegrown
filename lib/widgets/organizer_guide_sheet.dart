// lib/widgets/organizer_guide_sheet.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/elo_calculator.dart';

/// "How running a game works": the organizer's counterpart to the athletes'
/// points explainer, and the only place the whole job is laid out end to end.
///
/// Organizers had no help anywhere: onboarding is written for athletes, and
/// the step that closes a game (every player's stats) was mentioned only in a
/// snackbar. Opened from Home's to-do card and from Add Stats.
void showOrganizerGuideSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => _OrganizerGuide(scrollController: ctrl),
    ),
  );
}

class _OrganizerGuide extends StatelessWidget {
  final ScrollController scrollController;
  const _OrganizerGuide({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Text('How running a game works',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            'Every game goes through the same four steps. Your to-do list on '
            'Home shows whenever one of them is waiting on you.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        const _Step(
          number: 1,
          title: 'Create and publish',
          body: 'Pick the sport, Liga game or Tune-up, the date and the venue, '
              "then a coach's team for each side. Publishing tells every "
              'player and both coaches. A draft stays private until you '
              'publish it from its event page.',
        ),
        const _Step(
          number: 2,
          title: 'Game day',
          body: 'Players and coaches get a reminder the evening before and an '
              'hour before kick-off. Nothing to enter until the game starts.',
        ),
        const _Step(
          number: 3,
          title: 'Record the score',
          body: 'Once kick-off has passed, open the game and tap Record Match '
              'Results. Untick anyone who sat out and enter the final score. '
              "It can't be changed afterwards, so check it before you confirm.",
        ),
        const _Step(
          number: 4,
          title: "Add each player's stats",
          body: 'Add Stats opens on the game straight after the score. Enter '
              'one player at a time; the count shows how many are left. When '
              'the last player is saved, ratings update and the game is '
              'complete.',
          last: true,
        ),
        const SizedBox(height: 8),
        Text('GOOD TO KNOW',
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        const _Note(
          icon: LucideIcons.trophy,
          title: 'Liga game or Tune-up',
          body: 'A Liga game is official: it awards Homegrown points and moves '
              'Elo ratings. A tune-up is practice or an exhibition, so stats '
              'are kept but nobody gains points or Elo.',
        ),
        const _Note(
          icon: LucideIcons.swords,
          title: 'Elo rating',
          body: "Each player's rating in one sport, starting at "
              '$kStartingRating. Winning raises it and losing lowers it, more '
              'so against a stronger side. It only moves once every '
              "player's stats are in.",
        ),
        const _Note(
          icon: LucideIcons.mapPin,
          title: 'Public or private',
          body: 'Public games appear on the Game Directory map for everyone. '
              'Private games stay off the map; only the teams in them see '
              'them in their lists.',
        ),
        const _Note(
          icon: LucideIcons.network,
          title: 'Tournaments',
          body: 'A tournament runs several teams down to one champion. Draw '
              'the bracket from Home, then schedule each matchup. Recording a '
              'result moves the winner on by itself. Seeds 1 and 2 can only '
              'meet in the final, and a bye sends a team straight to the next '
              "round when the numbers don't divide evenly. Organizing more "
              'than one sport? Draw a separate bracket for each; they run '
              'side by side.',
        ),
        const _Note(
          icon: LucideIcons.calendarX,
          title: "When a game can't go ahead",
          body: 'Cancel it from the bottom of its event page, and everyone on '
              'it is told. A draft can simply be deleted. Once a score is '
              "recorded the game counts as played and can't be cancelled.",
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Got it'),
          ),
        ),
      ],
    );
  }
}

/// One numbered step, with a line down to the next so the four read as a
/// sequence rather than a list of unrelated tips.
class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final bool last;
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppTheme.accent, shape: BoxShape.circle),
                child: Text('$number',
                    style: const TextStyle(
                        color: AppTheme.buttonFg,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.border),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: last ? 16 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Note({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: AppTheme.accent, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(body,
                      style: TextStyle(
                          color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
