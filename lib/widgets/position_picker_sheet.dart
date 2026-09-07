// lib/widgets/position_picker_sheet.dart
import 'package:flutter/material.dart';
import '../constants/sport_positions.dart';
import '../theme/app_theme.dart';

/// Shows the shared position-selection bottom sheet, listing only the
/// positions that belong to [sports]. Returns the selected position, or null
/// if the sheet was dismissed.
///
/// Deliberately lighter than [showBarangayPickerSheet]: the options come from
/// a const rather than a service, and there are at most fourteen of them, so
/// there is no search field, no loading state and no fixed sheet height —
/// a badminton-only athlete gets a sheet three rows tall.
Future<String?> showPositionPickerSheet(BuildContext context,
    {required List<String> sports, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PositionPickerSheet(sports: sports, selected: selected),
  );
}

class _PositionPickerSheet extends StatelessWidget {
  final List<String> sports;
  final String? selected;
  const _PositionPickerSheet({required this.sports, this.selected});

  /// A sport heading above its own positions. Only worth showing when the
  /// athlete plays more than one sport — a single-sport list needs no label
  /// telling it what it already is.
  Widget _sportHeader(String sport) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(sport.toUpperCase(),
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _positionTile(BuildContext context, String position) {
    final sel = position == selected;
    return ListTile(
      dense: true,
      title: Text(position,
          style: TextStyle(
              color: sel ? AppTheme.accentText : AppTheme.textPrimary,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14)),
      trailing: sel
          ? const Icon(Icons.check_circle_rounded,
              color: AppTheme.accent, size: 20)
          : null,
      onTap: () => Navigator.pop(context, position),
    );
  }

  List<Widget> _rows(BuildContext context) {
    // Grouped by sport when there's more than one, so "Center" and "Setter"
    // don't sit in one undifferentiated column.
    final grouped = sports.length > 1;
    if (!grouped) {
      return positionsForSports(sports)
          .map((p) => _positionTile(context, p))
          .toList();
    }
    final out = <Widget>[];
    for (final sport in kSportPositions.keys) {
      if (!sports.contains(sport)) continue;
      out.add(_sportHeader(sport));
      out.addAll(kSportPositions[sport]!.map((p) => _positionTile(context, p)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('Select Position',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        // Caps the sheet at a little over half the screen so a two- or
        // three-sport list scrolls instead of running off the top.
        Flexible(
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: _rows(context)),
        ),
      ]),
    );
  }
}
