// test/widgets/privacy_consent_text_test.dart
//
// The consent line is the one place a new user is shown what they agree to by
// signing up, so what it must keep doing is name both documents as links. The
// links themselves open a browser, which a widget test cannot follow; these
// check that both are there and wired, and that both point somewhere real.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/app_links.dart';
import 'package:homegrown/widgets/privacy_consent_text.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// The spans of the rendered consent line, flattened.
List<TextSpan> _spans(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.descendant(
    of: find.byType(PrivacyConsentText),
    matching: find.byType(RichText),
  ));
  final spans = <TextSpan>[];
  rich.text.visitChildren((span) {
    if (span is TextSpan) spans.add(span);
    return true;
  });
  return spans;
}

TextSpan _span(WidgetTester tester, String text) =>
    _spans(tester).singleWhere((s) => s.text == text);

String _plain(WidgetTester tester) =>
    _spans(tester).map((s) => s.text ?? '').join();

void main() {
  testWidgets('names both the Terms of Use and the Privacy Policy as links',
      (tester) async {
    await tester.pumpWidget(_host(const PrivacyConsentText()));

    expect(_span(tester, 'Terms of Use').recognizer,
        isA<TapGestureRecognizer>());
    expect(_span(tester, 'Privacy Policy').recognizer,
        isA<TapGestureRecognizer>());
  });

  testWidgets('says creating an account is what counts as agreeing',
      (tester) async {
    await tester.pumpWidget(_host(const PrivacyConsentText()));

    expect(_plain(tester),
        'By creating an account you agree to our Terms of Use and Privacy '
        'Policy.');
  });

  testWidgets('takes a different lead for a screen that is not sign-up',
      (tester) async {
    await tester.pumpWidget(
        _host(const PrivacyConsentText(lead: 'By continuing')));

    expect(_plain(tester), startsWith('By continuing you agree to our '));
    expect(_plain(tester), isNot(contains('creating an account')));
  });

  test('both documents are served over HTTPS from the same site', () {
    final terms = Uri.parse(AppLinks.terms);
    final policy = Uri.parse(AppLinks.privacyPolicy);

    expect(terms.scheme, 'https');
    expect(terms.host, policy.host);
    expect(terms.path, endsWith('/terms.html'));
  });
}
