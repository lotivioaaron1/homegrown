// lib/utils/event_types.dart
//
// What an event's type means. The panel asked what separated Friendly,
// Tournament and League when every game counted the same; now the type
// decides something. A Liga game is an official match that counts toward
// Elo and points, a tune-up is practice or exhibition that doesn't, and a
// Tournament game is one of a bracket's matchups (the Cup format), which the
// bracket creates itself. This mirrors how local competitions run: an SK
// Liga or Mayor's Cup league, a Governor's Cup knockout, and tune-up games
// between them.

const kLigaGame = 'Liga game';
const kTuneUp = 'Tune-up';

/// Set on a bracket's own events by TournamentService; never picked by hand.
const kTournamentType = 'Tournament';

/// What an organizer picks from when creating or editing an event.
const kPickableEventTypes = [kLigaGame, kTuneUp];

/// What each choice means, shown under the picker.
String eventTypeHint(String type) => switch (type) {
      kTuneUp =>
        'Practice or exhibition — stats are kept, but no Elo or points.',
      kLigaGame => 'Official game — counts toward Elo and points.',
      _ => '',
    };

/// Whether a game of this type changes Elo and awards points. Only tune-ups
/// (and the old Friendly, which meant the same) don't; an event saved with
/// no type still counts, as it always has.
bool countsTowardRankings(String? eventType) =>
    eventType != kTuneUp && eventType != 'Friendly';

/// An event's type in the current words: events saved as Friendly or League
/// read as Tune-up and Liga game.
String eventTypeLabel(String? stored) => switch (stored) {
      'Friendly' => kTuneUp,
      'League' => kLigaGame,
      _ => stored ?? '',
    };

/// The choice the Edit picker starts on for a stored type, or null to leave
/// it for the organizer. A hand-made Tournament event reads as a Liga game,
/// since tournaments now come only from brackets.
String? pickableTypeFor(String? stored) => switch (stored) {
      kTuneUp || 'Friendly' => kTuneUp,
      kLigaGame || 'League' || kTournamentType => kLigaGame,
      _ => null,
    };
