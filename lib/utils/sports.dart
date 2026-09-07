// lib/utils/sports.dart

/// Reads the `primarySports` list off a `users/{uid}` document.
///
/// The same field carries an athlete's sports and a coach's, and the
/// `(doc['primarySports'] as List?)?.map(...)` unpacking is repeated across a
/// dozen screens. New code should come through here, because the result now
/// decides who a coach may scout: a malformed or missing field must degrade
/// to "no sports" rather than throwing part-way through building a query.
List<String> sportsOf(Map<String, dynamic>? user) {
  final raw = user?['primarySports'];
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

/// Whether a coach and an athlete share at least one sport — the rule that
/// decides who appears in Scout and who may be invited to a team.
///
/// Overlap rather than equality, because both sides are lists: a coach may
/// coach basketball and volleyball, and an athlete may play both. Empty on
/// either side is deliberately no match, so a coach whose profile has no
/// sports set matches nobody instead of everybody.
bool sportsOverlap(List<String> a, List<String> b) =>
    a.any(b.contains);
