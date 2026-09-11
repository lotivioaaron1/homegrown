// lib/constants/sport_icons.dart

import 'package:flutter/material.dart';

import 'sport_positions.dart';

/// The outline icon for a sport, for the muted info rows and pickers that
/// used to show a basketball whatever the sport was — a volleyball event's
/// detail screen and a badminton player's position picker both did.
///
/// Material has no badminton glyph, so badminton uses the racket icon, which
/// is the closest silhouette. The coloured sport balls (🏀🏐🏸) on Rankings,
/// Games and Scout are a separate vocabulary and are left alone.
IconData sportIcon(String? sport) {
  switch (sport) {
    case 'Basketball':
      return Icons.sports_basketball_outlined;
    case 'Volleyball':
      return Icons.sports_volleyball_outlined;
    case 'Badminton':
      return Icons.sports_tennis_outlined;
    default:
      return Icons.sports_outlined;
  }
}

/// The icon for a position row: the sport [position] belongs to when it is
/// one of [sports]' catalog positions, otherwise the first of [sports].
///
/// A multi-sport athlete's row should follow the position they picked — a
/// Setter shows a volleyball even if basketball was ticked first.
IconData positionIcon(String position, List<String> sports) {
  for (final entry in kSportPositions.entries) {
    if (sports.contains(entry.key) && entry.value.contains(position)) {
      return sportIcon(entry.key);
    }
  }
  return sportIcon(sports.isEmpty ? null : sports.first);
}
