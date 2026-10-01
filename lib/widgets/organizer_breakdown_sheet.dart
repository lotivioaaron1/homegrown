// lib/widgets/organizer_breakdown_sheet.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/organizer_breakdown.dart';

/// What sits behind Events Created on the organizer's own profile: the same
/// events counted by status, by sport, and by whether a bracket made them.
///
/// A summary, not a list — My Events already lists every event, and the
/// footer button goes there.
void showEventBreakdownSheet(BuildContext context, String organizerId) =>
    _show(context, _BreakdownSheet(organizerId: organizerId, events: true));

/// What sits behind Tournaments Run, counted by status and sport, with a way
/// into the Tournaments list.
void showTournamentBreakdownSheet(BuildContext context, String organizerId) =>
    _show(context, _BreakdownSheet(organizerId: organizerId, events: false));

void _show(BuildContext context, Widget sheet) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => sheet,
  );
}

class _BreakdownSheet extends StatefulWidget {
  final String organizerId;

  /// Events when true, tournaments when false.
  final bool events;

  const _BreakdownSheet({required this.organizerId, required this.events});

  @override
  State<_BreakdownSheet> createState() => _BreakdownSheetState();
}

class _BreakdownSheetState extends State<_BreakdownSheet> {
  late final Future<List<Map<String, dynamic>>> _docs;

  @override
  void initState() {
    super.initState();
    // Deliberately no kMaxListQuery limit: these are counts, and a cap would
    // make them wrong rather than just shorter. Equality only, no orderBy, so
    // the automatic index serves it.
    _docs = FirebaseFirestore.instance
        .collection(widget.events ? 'events' : 'tournaments')
        .where('organizerId', isEqualTo: widget.organizerId)
        .get()
        .then((s) => [for (final d in s.docs) d.data()]);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.events ? 'Events Created' : 'Tournaments Run';
    return SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _docs,
        builder: (context, snap) {
          final loaded = snap.hasData && !snap.hasError;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (loaded)
                    Text('${snap.data!.length}',
                        style: TextStyle(
                            color: AppTheme.accentText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 4),
                Text(
                    widget.events
                        ? 'Counted the same way as My Events.'
                        : 'Counted the same way as your Tournaments list.',
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                const SizedBox(height: 18),
                if (snap.hasError)
                  _message(friendlyError(snap.error))
                else if (!loaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2.5),
                    ),
                  )
                else if (snap.data!.isEmpty)
                  _message(widget.events
                      ? 'No events yet.'
                      : 'No tournaments yet.')
                else
                  ..._sections(snap.data!),
                const SizedBox(height: 4),
                _seeAllButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(List<Map<String, dynamic>> docs) {
    if (widget.events) {
      final b = eventBreakdown(docs);
      return [
        _section('By status', b.byStatus),
        _section('By sport', b.bySport),
        // Only worth a section when brackets have added games to the total.
        if (b.tournamentGames > 0)
          _section('How they were made', [
            BreakdownRow('Games you scheduled', b.scheduled),
            BreakdownRow('Tournament games', b.tournamentGames),
          ]),
      ];
    }
    final b = tournamentBreakdown(docs);
    return [
      _section('By status', b.byStatus),
      _section('By sport', b.bySport),
    ];
  }

  Widget _section(String heading, List<BreakdownRow> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading.toUpperCase(),
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Expanded(
                        child: Text(rows[i].label,
                            style:
                                TextStyle(color: AppTheme.sub, fontSize: 13)),
                      ),
                      Text('${rows[i].count}',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
        ),
      );

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(text,
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
      );

  /// Into the full list, which is also where New lives — so an empty
  /// breakdown is never a dead end.
  Widget _seeAllButton(BuildContext context) {
    final label =
        widget.events ? 'See all in My Events' : 'See all tournaments';
    final route = widget.events ? '/events' : '/tournaments';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Get.toNamed(route);
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.accentText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.accentText, size: 18),
        ]),
      ),
    );
  }
}
