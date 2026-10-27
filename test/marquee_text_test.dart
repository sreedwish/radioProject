import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_app/widgets/marquee_text.dart';

Widget _host(String text) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 200, child: MarqueeText(text))),
);

double _offset(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(MarqueeText),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .x;

void main() {
  testWidgets('short text is static', (tester) async {
    await tester.pumpWidget(_host('Hi'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(OverflowBox), findsNothing);
  });

  testWidgets('long text scrolls and loops', (tester) async {
    await tester.pumpWidget(
      _host('A really long radio station name that overflows'),
    );
    await tester.pump();
    final start = _offset(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_offset(tester), lessThan(start - 20));
    await tester.pump(const Duration(seconds: 30));
    expect(_offset(tester), lessThanOrEqualTo(0));
  });
}
