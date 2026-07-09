// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/main.dart';

void main() {
  testWidgets('Homegrown app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HomegrownApp());
  });
}