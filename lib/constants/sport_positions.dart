// lib/constants/sport_positions.dart
library;

/// The canonical playing positions for each sport the app supports.
///
/// Position used to be free text on three separate screens, so the same
/// position reached Firestore as "Point Guard", "point guard", "PG" and
/// "point gaurd" — and `users/{uid}.position` is displayed verbatim in a dozen
/// places (Scout cards, the leaderboard, event rosters), so every typo stayed
/// visible to strangers. Picking from this list is the only way to set a
/// position now, which is why there is deliberately no "Other" entry: an
/// escape hatch would reopen exactly the problem the list exists to close.
///
/// The keys must stay in step with the `_kSports` list duplicated across the
/// registration and profile screens (`Basketball`, `Volleyball`, `Badminton`).
/// Adding a sport to the app means adding its positions here too — an unknown
/// sport is skipped by [positionsForSports] rather than throwing, so a mismatch
/// fails as an empty picker rather than a crash.
const Map<String, List<String>> kSportPositions = {
  'Basketball': [
    'Point Guard',
    'Shooting Guard',
    'Small Forward',
    'Power Forward',
    'Center',
  ],
  'Volleyball': [
    'Setter',
    'Outside Hitter',
    'Opposite Hitter',
    'Middle Blocker',
    'Libero',
    'Defensive Specialist',
  ],
  'Badminton': [
    'Singles',
    'Doubles',
    'Mixed Doubles',
  ],
};

/// Every position available to an athlete playing [sports], pooled into one
/// list with duplicates removed.
///
/// Iterates [kSportPositions] in key order rather than the order the athlete
/// happened to tap their sports, so the picker shows the same sequence every
/// time it is opened. Sports with no entry in the map are skipped.
List<String> positionsForSports(List<String> sports) {
  final out = <String>[];
  for (final sport in kSportPositions.keys) {
    if (!sports.contains(sport)) continue;
    for (final position in kSportPositions[sport]!) {
      if (!out.contains(position)) out.add(position);
    }
  }
  return out;
}

/// Whether [position] appears anywhere in this catalog, for any sport.
///
/// Distinguishes a value the picker produced from legacy free text typed
/// before the picker existed — which matters when deciding whether clearing a
/// position is a correction or silent data loss.
bool isCatalogPosition(String position) =>
    kSportPositions.values.any((list) => list.contains(position));

/// Whether [position] is a real position for one of [sports].
///
/// False for a blank value, for legacy free text typed before the picker
/// existed, and for a genuine position belonging to a sport the athlete no
/// longer plays — the last case is what lets the forms clear a selection that
/// has been orphaned by unticking a sport.
bool isKnownPosition(String position, List<String> sports) =>
    position.isNotEmpty && positionsForSports(sports).contains(position);
