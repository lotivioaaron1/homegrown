// lib/constants/event_min_players.dart

/// The fewest players each side of an event needs, by sport: a full
/// starting lineup for the team sports, and one for badminton so singles
/// stays possible. Keys match kSportPositions.
const Map<String, int> kMinPlayersPerSide = {
  'Basketball': 5,
  'Volleyball': 6,
  'Badminton': 1,
};
