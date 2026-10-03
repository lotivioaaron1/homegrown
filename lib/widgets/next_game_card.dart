// lib/widgets/next_game_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/firestore_helpers.dart';
import '../utils/next_game.dart';

/// The soonest game the viewer is in, on Home under the hero card, opening
/// that game's detail screen.
///
/// Takes the games stream rather than building it, so Home decides whose
/// games these are — an athlete's (`playerUids`) or a coach's
/// (`teamACoachId`/`teamBCoachId`) — with the same query its Upcoming Games
/// list already uses.
///
/// Renders nothing while loading, on error, or when there is no game: the
/// Upcoming Games section further down already explains an empty schedule,
/// and a second empty state here would only push the rest of Home down.
class NextGameCard extends StatelessWidget {
  final Stream<QuerySnapshot> stream;

  /// Space around the card, applied only when there is a card to show.
  final EdgeInsets padding;

  const NextGameCard({
    super.key,
    required this.stream,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final now = DateTime.now();
        final next = nextGame<QueryDocumentSnapshot>(
          snapshot.data?.docs ?? const [],
          dataOf: (doc) => doc.data() as Map<String, dynamic>,
          now: now,
        );
        if (next == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: NextGameView(
            event: next.data() as Map<String, dynamic>,
            now: now,
            onTap: () => Get.toNamed('/events/detail',
                arguments: {'eventId': next.id}),
          ),
        );
      },
    );
  }
}

/// The card itself, separate from the loading so it can be rendered in a
/// test without Firebase.
class NextGameView extends StatelessWidget {
  final Map<String, dynamic> event;
  final DateTime now;
  final VoidCallback onTap;

  const NextGameView({
    super.key,
    required this.event,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = asTimestamp(event['eventDate'])?.toDate();
    // nextGame never hands over a dateless game, but this is a public widget.
    if (date == null) return const SizedBox.shrink();

    final kickoff = kickoffLabel(date, now: now);
    final name = asString(event['name']).trim();
    final venue = asString(event['venue']).trim();
    // Gold only on the day itself, so it still means something: every other
    // day the card is a neutral row like the rest of Home.
    final gameDay = isGameDay(date, now: now);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [
        gameDay ? 'Game day' : 'Next game',
        kickoff,
        if (name.isNotEmpty) name,
        if (venue.isNotEmpty) 'at $venue',
      ].join(', '),
      child: Material(
        color: gameDay ? AppTheme.accentSurface : AppTheme.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: gameDay ? AppTheme.accent : AppTheme.border)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: gameDay ? AppTheme.accent : AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: gameDay
                        ? null
                        : Border.all(color: AppTheme.accent)),
                child: Icon(LucideIcons.calendarClock,
                    color: gameDay ? AppTheme.buttonFg : AppTheme.accentText,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gameDay ? 'GAME DAY' : 'NEXT GAME',
                          style: TextStyle(
                              color: gameDay
                                  ? AppTheme.accentText
                                  : AppTheme.sub,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      const SizedBox(height: 3),
                      // The kickoff leads: "when" is the question this card
                      // exists to answer.
                      Text(kickoff,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      if (name.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: AppTheme.sub, fontSize: 12)),
                      ],
                      if (venue.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(LucideIcons.mapPin,
                              color: AppTheme.muted, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppTheme.muted, fontSize: 11)),
                          ),
                        ]),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.muted, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
