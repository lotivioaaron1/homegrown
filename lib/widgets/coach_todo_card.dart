// lib/widgets/coach_todo_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/coach_todo.dart';
import '../utils/team_name.dart';

/// The top of a coach's Home: what is waiting on them before their team can
/// get going. The coach's counterpart to `OrganizerTodoCard`.
///
/// Lists a missing sport (without one Scout shows nobody, and Home used to
/// leave the coach to discover that two screens later), invites still
/// waiting for an answer (which left no trace on Home while the roster was
/// empty), and a missing team name. Renders nothing once all three are
/// settled, so an established coach's Home isn't carrying an empty card.
class CoachTodoCard extends StatefulWidget {
  final String uid;

  /// The coach's live `users/{uid}` map from Home's own stream, so the card
  /// updates the moment Edit Profile saves a sport or a team name.
  final Map<String, dynamic> user;

  const CoachTodoCard({super.key, required this.uid, required this.user});

  @override
  State<CoachTodoCard> createState() => _CoachTodoCardState();
}

class _CoachTodoCardState extends State<CoachTodoCard> {
  // Held here rather than built in build(), so a Home rebuild doesn't
  // re-subscribe.
  late final _pending = TeamService.streamSentPending(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pending,
      builder: (context, snap) {
        // Nothing until the invites have loaded, rather than flashing the
        // other rows and then pushing them down. A failed read counts as no
        // invites, so the profile rows still show.
        if (!snap.hasData && !snap.hasError) return const SizedBox.shrink();
        final todo = coachTodo(
          user: widget.user,
          pendingInvites: snap.data?.docs.length ?? 0,
        );
        if (todo.isEmpty) return const SizedBox.shrink();
        return _section(_TodoList(
          todo: todo,
          teamName: teamDisplayName(
              teamOrganization: widget.user['teamOrganization'] as String?,
              coachName: widget.user['fullName'] as String?),
        ));
      },
    );
  }

  Widget _section(Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('TO DO',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ],
      );
}

class _TodoList extends StatelessWidget {
  final CoachTodo todo;

  /// What athletes see while the team has no name of its own.
  final String teamName;

  const _TodoList({required this.todo, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (todo.needsSport)
        _TodoRow(
          icon: LucideIcons.trophy,
          title: 'Choose the sport you coach',
          subtitle: 'Scout shows athletes from the sports you coach',
          onTap: () => Get.to(() => const EditProfileScreen()),
        ),
      if (todo.pendingInvites > 0)
        _TodoRow(
          icon: LucideIcons.mail,
          title: coachInvitesLabel(todo.pendingInvites),
          subtitle: 'Sent from Scout',
          onTap: () => Get.toNamed('/team/roster'),
        ),
      // My Team, not Edit Profile: the team name is renamed from the team
      // card there, and Edit Profile has no field for it.
      if (todo.needsTeamName)
        _TodoRow(
          icon: LucideIcons.users,
          title: 'Name your team',
          subtitle: 'Athletes see “$teamName” until you do',
          onTap: () => Get.toNamed('/team/roster'),
        ),
    ];
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
  final String subtitle;
  final VoidCallback onTap;

  const _TodoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
                  color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.accentText, size: 17),
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
                  Text(subtitle,
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
