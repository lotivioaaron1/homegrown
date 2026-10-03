// tool/seed_tournament_stats.dart
//
// Finishes a demo tournament and fills in every player's stats, signed in as
// the tournament's organizer and going through the same service code the
// app's screens call: Record Match's bracket commit (RatingService.recordMatch
// plus TournamentService.stageAdvance), Add Stats' save, and the Elo update
// once a game's stats are all in. The security rules apply exactly as they
// do in the app.
//
// It is a separate entry point, not part of the app. Chrome runs it without
// touching the app installed on a phone or emulator:
//
//   flutter run -d chrome -t tool/seed_tournament_stats.dart
//     --dart-define=ORG_EMAIL=<organizer email>
//     --dart-define=ORG_PASSWORD=<password>
//     --dart-define=TOURNAMENT=<tournament id>
//     [--dart-define=APPLY=true]
//
// Without APPLY it prints everything it would record and write, and changes
// nothing. Re-running is safe: a game with a result isn't recorded again, and
// a player who already has stats for a game is skipped.
//
// Stats are basketball box scores that split each team's final score
// exactly, checked against the same limit Add Stats enforces.

// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:homegrown/firebase_options.dart';
import 'package:homegrown/models/bracket_slot.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/services/notification_service.dart';
import 'package:homegrown/services/rating_service.dart';
import 'package:homegrown/services/tournament_service.dart';
import 'package:homegrown/utils/stat_limits.dart';
import 'package:homegrown/utils/stat_scoring.dart';
import 'package:uuid/uuid.dart';

const _email = String.fromEnvironment('ORG_EMAIL');
const _password = String.fromEnvironment('ORG_PASSWORD');
const _tournamentId = String.fromEnvironment('TOURNAMENT');
const _apply = bool.fromEnvironment('APPLY');

final _db = FirebaseFirestore.instance;

// Seeded, so a dry run and the run that follows it write the same numbers.
final _rnd = Random(29);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var code = 0;
  try {
    await _run();
  } catch (e, st) {
    print('FAILED: $e\n$st');
    code = 1;
  }
  // A browser tab can't exit; stop the run from the terminal instead.
  if (!kIsWeb) exit(code);
}

Future<void> _run() async {
  if (_email.isEmpty || _password.isEmpty || _tournamentId.isEmpty) {
    throw ArgumentError('ORG_EMAIL, ORG_PASSWORD and TOURNAMENT are required.');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final cred = await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: _email, password: _password);
  final organizerId = cred.user!.uid;
  print(_apply
      ? 'Mode: APPLY, writing to Firebase.'
      : 'Mode: DRY RUN, nothing will be written. Add APPLY=true to commit.');

  final tSnap = await _db.collection('tournaments').doc(_tournamentId).get();
  final tData = tSnap.data();
  if (tData == null) throw StateError('No tournament $_tournamentId.');
  final tournament = Tournament.fromMap(tSnap.id, tData);
  if (tournament.organizerId != organizerId) {
    throw StateError('${cred.user!.email} does not run ${tournament.name}.');
  }
  if (tournament.sport != 'Basketball') {
    throw StateError('Only basketball box scores are generated.');
  }
  print('Tournament: ${tournament.name} (${tournament.entrantCount} teams)\n');

  // 1. Record every scheduled game whose kickoff has passed.
  var slots = await _slots(tournament.id);
  for (final slot in slots.where((s) => s.isScheduled)) {
    await _record(tournament, slot, slots, organizerId);
  }

  // 2. Stats for every recorded game, then its Elo update.
  if (_apply) slots = await _slots(tournament.id);
  for (final slot in slots.where((s) => s.matchId != null)) {
    await _fillStats(tournament, slot, organizerId);
  }

  await FirebaseAuth.instance.signOut();
  print('\nDone.');
}

Future<List<BracketSlot>> _slots(String tournamentId) async =>
    TournamentService.slotsFrom(
        await TournamentService.slotsOf(tournamentId).get());

BracketSlot? _find(Iterable<BracketSlot> slots, bool Function(BracketSlot) test) {
  for (final s in slots) {
    if (test(s)) return s;
  }
  return null;
}

/// Record Match's bracket commit: the match and the bracket move in one
/// batch, exactly as _recordBracketMatch does it.
Future<void> _record(Tournament t, BracketSlot slot, List<BracketSlot> slots,
    String organizerId) async {
  final ev = (await _db.collection('events').doc(slot.eventId).get()).data();
  if (ev == null) return print('  ${slot.id}: event missing, skipped');
  if (ev['hasMatchData'] == true) {
    return print('  ${slot.id}: already recorded, skipped');
  }
  final kickoff = (ev['eventDate'] as Timestamp).toDate();
  if (kickoff.isAfter(DateTime.now())) {
    return print('  ${slot.id}: kicks off $kickoff, not recorded yet');
  }

  final players = (ev['players'] as List).cast<Map>();
  final sideA = [for (final p in players) if (p['team'] == 'A') p['uid'] as String];
  final sideB = [for (final p in players) if (p['team'] == 'B') p['uid'] as String];

  // A believable close game.
  final high = 55 + _rnd.nextInt(26);
  final low = high - 2 - _rnd.nextInt(11);
  final aWins = _rnd.nextBool();
  final scoreA = aWins ? high : low;
  final scoreB = aWins ? low : high;
  print('Record ${slot.isThirdPlace ? 'battle for third' : slot.id}: '
      '${slot.entrantA?.teamName} $scoreA – $scoreB ${slot.entrantB?.teamName}');
  if (!_apply) return;

  final batch = _db.batch();
  final matchId = await RatingService.recordMatch(
    eventId: slot.eventId!,
    sport: t.sport,
    sideA: sideA,
    sideB: sideB,
    scoreA: scoreA,
    scoreB: scoreB,
    recordedBy: organizerId,
    writeBatch: batch,
  );
  await TournamentService.stageAdvance(
    batch,
    tournament: t,
    slot: slot,
    nextSlot: _find(slots, (s) => s.id == slot.nextSlotId),
    matchId: matchId,
    scoreA: scoreA,
    scoreB: scoreB,
    winnerSide: scoreA > scoreB ? 'A' : 'B',
    thirdPlaceSlot: _find(slots, (s) => s.isThirdPlace),
  );
  await batch.commit();
}

Future<void> _fillStats(Tournament t, BracketSlot slot, String organizerId) async {
  final matchId = slot.matchId!;
  final match = (await _db.collection('matches').doc(matchId).get()).data();
  if (match == null) return;
  final ev = (await _db.collection('events').doc(match['eventId'] as String).get())
      .data()!;
  final byUid = {
    for (final p in (ev['players'] as List).cast<Map>()) p['uid'] as String: p,
  };

  final existing =
      await _db.collection('stats').where('matchId', isEqualTo: matchId).get();
  final entered = {
    for (final d in existing.docs)
      d['athleteId'] as String:
          ((d.data()['stats'] as Map?)?['points'] as num?)?.toInt() ?? 0,
  };

  final label = slot.isThirdPlace ? 'Battle for third' : slot.id;
  print('\n$label: ${ev['teamAName']} ${match['scoreA']} – '
      '${match['scoreB']} ${ev['teamBName']}');

  final sides = [
    (List<String>.from(match['sideA'] as List), (match['scoreA'] as num).toInt()),
    (List<String>.from(match['sideB'] as List), (match['scoreB'] as num).toInt()),
  ];
  for (final (uids, teamScore) in sides) {
    final todo = uids.where((u) => !entered.containsKey(u)).toList();
    if (todo.isEmpty) continue;
    final already =
        uids.where(entered.containsKey).fold<int>(0, (s, u) => s + entered[u]!);
    final lines = _boxScores(
        [for (final u in todo) byUid[u] ?? const {}], teamScore - already);

    for (var i = 0; i < todo.length; i++) {
      final uid = todo[i];
      final stats = lines[i];
      // The same limit Add Stats enforces.
      final cap = scoreCapFor(
        sport: t.sport,
        match: match,
        athleteId: uid,
        nameA: ev['teamAName'] as String? ?? 'Team A',
        nameB: ev['teamBName'] as String? ?? 'Team B',
        enteredByAthlete: entered,
      );
      final error = cap == null ? null : scoreCapError(cap, stats['points']!);
      if (error != null) throw StateError(error);

      final player = byUid[uid] ?? const {};
      print('  ${(player['fullName'] ?? uid).toString().padRight(22)} '
          '${stats['points']} pts  ${stats['rebounds']} reb  '
          '${stats['assists']} ast  ${stats['steals']} stl  '
          '${stats['blocks']} blk  ${stats['turnovers']} to');
      if (_apply) {
        await _saveStat(ev, player, uid, stats, matchId, organizerId);
      }
      entered[uid] = stats['points']!;
    }
  }

  if (_apply &&
      match['status'] == 'pending' &&
      await RatingService.allStatsSubmitted(
          matchId, [...List<String>.from(match['sideA']), ...List<String>.from(match['sideB'])])) {
    await RatingService.finalizeMatch(matchId);
    print('  ratings updated');
  }
}

/// Add Stats' save, field for field: the stat line, the athlete's points,
/// and their notification, in one batch.
Future<void> _saveStat(Map<String, dynamic> ev, Map player, String athleteId,
    Map<String, int> stats, String matchId, String organizerId) async {
  final sport = ev['sport'] as String;
  final statId = const Uuid().v4();
  final points = calcPointsAwarded(sport, stats);
  final batch = _db.batch();
  batch.set(_db.collection('stats').doc(statId), {
    'statId': statId,
    'eventId': ev['eventId'],
    'eventName': ev['name'],
    'organizerId': organizerId,
    'athleteId': athleteId,
    'athleteName': player['fullName'] ?? '',
    'sport': sport,
    'venue': ev['venue'] ?? '',
    'eventDate': ev['eventDate'],
    'stats': stats,
    'notes': '',
    'pointsAwarded': points,
    'matchId': matchId,
    'createdAt': FieldValue.serverTimestamp(),
  });
  batch.update(_db.collection('users').doc(athleteId),
      {'points': FieldValue.increment(points)});
  await NotificationService.create(
    userId: athleteId,
    type: 'stats_added',
    title: 'Stats recorded',
    body: 'You earned $points points in ${ev['name']}',
    relatedId: statId,
    writeBatch: batch,
  );
  await batch.commit();
}

/// Box scores for [players] whose points add up to exactly [total]: a spread
/// from a go-to scorer down to role players, with rebounds and blocks
/// leaning to the bigs and assists to the guards.
List<Map<String, int>> _boxScores(List<Map> players, int total) {
  final n = players.length;
  if (n == 0) return const [];
  final weights = [for (var i = 0; i < n; i++) 0.6 + _rnd.nextDouble()];
  final sum = weights.reduce((a, b) => a + b);
  final points = [for (final w in weights) (total * w / sum).floor()];
  var left = total - points.reduce((a, b) => a + b);
  for (var i = 0; left > 0; i++, left--) {
    points[i % n]++;
  }

  return [
    for (var i = 0; i < n; i++)
      () {
        final position = players[i]['position'] as String? ?? '';
        final big = position == 'Center' || position == 'Power Forward';
        final guard =
            position == 'Point Guard' || position == 'Shooting Guard';
        return {
          'points': points[i],
          'assists': guard ? 3 + _rnd.nextInt(6) : _rnd.nextInt(4),
          'rebounds': big ? 5 + _rnd.nextInt(8) : 1 + _rnd.nextInt(5),
          'steals': _rnd.nextInt(guard ? 4 : 3),
          'blocks': big ? _rnd.nextInt(4) : _rnd.nextInt(2),
          'turnovers': _rnd.nextInt(4),
        };
      }(),
  ];
}
