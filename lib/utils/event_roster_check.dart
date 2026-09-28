// lib/utils/event_roster_check.dart
import '../constants/event_min_players.dart';

int minPlayersPerSide(String sport) => kMinPlayersPerSide[sport] ?? 1;

/// Why an event's teams aren't ready yet, or null when both sides are
/// picked and each meets the sport's minimum. Team A is checked first.
String? teamsProblem({
  required String sport,
  required bool pickedA,
  required bool pickedB,
  required int countA,
  required int countB,
  required String nameA,
  required String nameB,
}) {
  if (!pickedA && !pickedB) return 'Pick a team for each side.';
  if (!pickedA) return 'Pick Team A before continuing.';
  if (!pickedB) return 'Pick Team B before continuing.';

  final min = minPlayersPerSide(sport);
  for (final (name, count) in [(nameA, countA), (nameB, countB)]) {
    if (count >= min) continue;
    final has = count == 0
        ? 'has no players'
        : 'has only $count player${count == 1 ? '' : 's'}';
    return '$name $has. $sport needs at least $min per side.';
  }
  return null;
}
