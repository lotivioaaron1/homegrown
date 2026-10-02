import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/roster_labels.dart';

void main() {
  group('joinedLabel', () {
    final now = DateTime(2026, 10, 2, 18, 0);

    test('is empty when the join date is unknown', () {
      expect(joinedLabel(null, now: now), '');
    });

    test('says just now inside the first minute', () {
      expect(joinedLabel(now.subtract(const Duration(seconds: 30)), now: now),
          'Joined just now');
    });

    test('treats a slightly future timestamp as just now', () {
      expect(joinedLabel(now.add(const Duration(minutes: 2)), now: now),
          'Joined just now');
    });

    test('counts minutes, hours and days while recent', () {
      expect(joinedLabel(now.subtract(const Duration(minutes: 5)), now: now),
          'Joined 5m ago');
      expect(joinedLabel(now.subtract(const Duration(hours: 3)), now: now),
          'Joined 3h ago');
      expect(joinedLabel(now.subtract(const Duration(days: 6)), now: now),
          'Joined 6d ago');
    });

    test('switches to a date at a week, without a padded day', () {
      expect(joinedLabel(DateTime(2026, 9, 25, 18, 0), now: now),
          'Joined Sep 25');
      expect(joinedLabel(DateTime(2026, 9, 6), now: now), 'Joined Sep 6');
    });

    test('adds the year for a join in an earlier year', () {
      expect(joinedLabel(DateTime(2025, 9, 6), now: now),
          'Joined Sep 6, 2025');
    });
  });

  group('invitedLabel', () {
    final now = DateTime(2026, 10, 2, 18, 0);

    test('reads like the join label, with its own verb', () {
      expect(invitedLabel(null, now: now), '');
      expect(invitedLabel(now.subtract(const Duration(days: 2)), now: now),
          'Invited 2d ago');
      expect(invitedLabel(DateTime(2025, 12, 30), now: now),
          'Invited Dec 30, 2025');
    });
  });

  group('openSpotsLabel', () {
    test('counts the open spots', () {
      expect(openSpotsLabel(5, 15), '10 spots open');
    });

    test('is singular for the last spot', () {
      expect(openSpotsLabel(14, 15), '1 spot open');
    });

    test('says the roster is full at or past capacity', () {
      expect(openSpotsLabel(15, 15), 'Roster full');
      expect(openSpotsLabel(16, 15), 'Roster full');
    });
  });

  group('memberSubtitle', () {
    test('joins the position and the join date', () {
      expect(memberSubtitle('Point Guard', 'Joined Sep 6'),
          'Point Guard · Joined Sep 6');
    });

    test('drops whichever part is missing', () {
      expect(memberSubtitle('', 'Joined Sep 6'), 'Joined Sep 6');
      expect(memberSubtitle(null, 'Joined Sep 6'), 'Joined Sep 6');
      expect(memberSubtitle('  Setter ', ''), 'Setter');
      expect(memberSubtitle(null, ''), '');
    });
  });
}
