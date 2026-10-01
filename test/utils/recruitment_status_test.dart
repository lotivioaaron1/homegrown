// test/utils/recruitment_status_test.dart
//
// A rostered athlete's pill used to read "Not Available", which never said why.
// It now names the team they play for.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/recruitment_status.dart';

void main() {
  group('recruitmentBadge', () {
    test('open to recruitment', () {
      final badge = recruitmentBadge(isOpen: true, teamNames: const []);
      expect(badge.kind, RecruitmentKind.open);
      expect(badge.label, 'Open to Recruitment');
    });

    test('open wins over a team — the athlete reopened it on purpose', () {
      final badge =
          recruitmentBadge(isOpen: true, teamNames: const ['Rawis Rockets']);
      expect(badge.kind, RecruitmentKind.open);
      expect(badge.label, 'Open to Recruitment');
    });

    test('closed and on one team names it', () {
      final badge =
          recruitmentBadge(isOpen: false, teamNames: const ['Rawis Rockets']);
      expect(badge.kind, RecruitmentKind.onTeam);
      expect(badge.label, 'Plays for Rawis Rockets');
    });

    test('closed and on a team per sport names each', () {
      final badge = recruitmentBadge(
          isOpen: false, teamNames: const ['Rawis Rockets', 'Rawis Spikers']);
      expect(badge.label, 'Plays for Rawis Rockets · Rawis Spikers');
    });

    test('closed with no team is not available', () {
      final badge = recruitmentBadge(isOpen: false, teamNames: const []);
      expect(badge.kind, RecruitmentKind.unavailable);
      expect(badge.label, 'Not Available');
    });

    test('blank names are skipped, and only blanks counts as no team', () {
      expect(
          recruitmentBadge(isOpen: false, teamNames: const ['  ', 'Hoopers'])
              .label,
          'Plays for Hoopers');
      expect(
          recruitmentBadge(isOpen: false, teamNames: const ['', '  ']).kind,
          RecruitmentKind.unavailable);
    });

    test('names are trimmed and a repeated name is shown once', () {
      expect(
          recruitmentBadge(
                  isOpen: false, teamNames: const [' Hoopers ', 'Hoopers'])
              .label,
          'Plays for Hoopers');
    });
  });
}
