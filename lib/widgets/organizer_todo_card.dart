// lib/widgets/organizer_todo_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/query_limits.dart';
import '../theme/app_theme.dart';
import '../utils/organizer_status.dart';
import '../utils/organizer_todo.dart';
import 'organizer_guide_sheet.dart';

/// The top of an organizer's Home: what is waiting on them, and the way into
/// "How running a game works".
///
/// Before approval it explains the wait instead, since every Create button is
/// blocked until then and Home otherwise looked exactly like an approved
/// organizer's with nothing on it. Once approved it lists the games that
/// need a score, the games still missing player stats (the step that
/// actually moves ratings, and the one organizers didn't know about), and
/// unpublished drafts. Each row opens the game that has waited longest.
class OrganizerTodoCard extends StatefulWidget {
  final String uid;
  final String? organizerStatus;
  const OrganizerTodoCard({
    super.key,
    required this.uid,
    required this.organizerStatus,
  });

  @override
  State<OrganizerTodoCard> createState() => _OrganizerTodoCardState();
}

class _OrganizerTodoCardState extends State<OrganizerTodoCard> {
  // Held here rather than built in build(), so a Home rebuild doesn't
  // re-subscribe.
  late final _events = FirebaseFirestore.instance
      .collection('events')
      .where('organizerId', isEqualTo: widget.uid)
      .limit(kMaxListQuery)
      .snapshots();
  // Equality filters only, so no composite index is needed.
  late final _pendingMatches = FirebaseFirestore.instance
      .collection('matches')
      .where('recordedBy', isEqualTo: widget.uid)
      .where('status', isEqualTo: 'pending')
      .limit(kMaxListQuery)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final statusCopy = organizerStatusCopy(widget.organizerStatus);
    if (statusCopy != null) {
      return _section(_StatusBanner(
          copy: statusCopy,
          refused: isRefusedOrganizer(widget.organizerStatus)));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _events,
      builder: (context, events) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _pendingMatches,
        builder: (context, matches) {
          // Nothing until both have loaded, rather than flashing "all caught
          // up" over games that are about to appear.
          if (!events.hasData || !matches.hasData) {
            return const SizedBox.shrink();
          }
          final todo = organizerTodo(
            events: [
              for (final d in events.data!.docs) {...d.data(), 'eventId': d.id},
            ],
            pendingMatches: [for (final d in matches.data!.docs) d.data()],
          );
          return _section(_TodoList(todo: todo));
        },
      ),
    );
  }

  Widget _section(Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('TO DO',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              GestureDetector(
                onTap: () => showOrganizerGuideSheet(context),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.help_outline_rounded,
                      color: AppTheme.accent, size: 13),
                  SizedBox(width: 4),
                  Text('How it works',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ],
      );
}

class _TodoList extends StatelessWidget {
  final OrganizerTodo todo;
  const _TodoList({required this.todo});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (todo.needsScore case final item?)
        _TodoRow(
          icon: LucideIcons.clipboardPen,
          title: todoScoreLabel(item.count),
          next: item.nextEventName,
          onTap: () => Get.toNamed('/matches/record',
              arguments: {'eventId': item.nextEventId}),
        ),
      if (todo.needsStats case final item?)
        _TodoRow(
          icon: LucideIcons.chartColumn,
          title: todoStatsLabel(item.count),
          next: item.nextEventName,
          onTap: () => Get.toNamed('/stats/add',
              arguments: {'eventId': item.nextEventId}),
        ),
      if (todo.drafts case final item?)
        _TodoRow(
          icon: LucideIcons.filePen,
          title: todoDraftsLabel(item.count),
          next: item.nextEventName,
          onTap: () => Get.toNamed('/events/detail',
              arguments: {'eventId': item.nextEventId}),
        ),
    ];
    if (rows.isEmpty) {
      // Also a brand-new organizer's first sight of Home, which is when the
      // guide is most useful, so the way into it is the row itself.
      rows.add(_TodoRow(
        icon: LucideIcons.circleCheck,
        title: "You're all caught up",
        next: null,
        subtitle: 'New to running games? See how it works.',
        muted: true,
        onTap: () => showOrganizerGuideSheet(context),
      ));
    }
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppTheme.border),
          rows[i],
        ],
      ]),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final IconData icon;
  final String title;

  /// The game the tap opens, shown as "Next: …".
  final String? next;

  /// Used instead of [next] when the row isn't about a game.
  final String? subtitle;

  /// For the caught-up row, which shouldn't look like a task.
  final bool muted;
  final VoidCallback onTap;

  const _TodoRow({
    required this.icon,
    required this.title,
    required this.next,
    required this.onTap,
    this.subtitle,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: muted ? AppTheme.cardNested : AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: muted ? AppTheme.muted : AppTheme.accent, size: 17),
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
                  const SizedBox(height: 2),
                  Text(next != null ? 'Next: $next' : subtitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
          ]),
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  final OrganizerStatusCopy copy;
  final bool refused;
  const _StatusBanner({required this.copy, required this.refused});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: refused ? AppTheme.card : AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: refused ? AppTheme.border : AppTheme.accent)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(refused ? Icons.block_rounded : Icons.hourglass_top_rounded,
              color: refused ? AppTheme.muted : AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.title,
                    style: TextStyle(
                        color: refused
                            ? AppTheme.textPrimary
                            : AppTheme.accentText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(copy.body,
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 12.5, height: 1.45)),
              ],
            ),
          ),
        ]),
      );
}
