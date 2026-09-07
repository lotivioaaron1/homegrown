// lib/constants/query_limits.dart

/// Ceilings on how many documents a single Firestore query may read.
///
/// Firestore bills per document read, so an unbounded query is an unbounded
/// bill that grows with the app's success — and the app has no backend to
/// enforce anything, so these caps are the only limit that exists.
///
/// These are cost ceilings, not page sizes. Each is set well above what a
/// community platform in one city will realistically hold, so in normal use
/// they never bind and behaviour is unchanged. They exist to stop an
/// unexpected data volume (or someone deliberately generating one) from
/// turning a screen into a five-figure read.
///
/// Where a limit would change *correctness* rather than just volume, it is
/// deliberately absent — see NotificationService.markAllRead and deleteAll,
/// which must genuinely touch every one of a user's own notifications.
library;

/// Scrollable "view all" lists: a user's events, public event listings.
const int kMaxListQuery = 100;

/// Map and locator views that load a set of pins in one shot.
const int kMaxMapQuery = 200;
