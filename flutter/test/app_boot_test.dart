import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/app/app.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('app boots to the home shell with a 5-tab bottom nav', (
    tester,
  ) async {
    await tester.pumpWidget(await wrapForTest(const NovaApp()));
    await tester.pumpAndSettle();

    // Shell present.
    expect(find.byType(NavigationBar), findsOneWidget);

    // Five customer destinations (labels are localized RU by default).
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);

    // Home placeholder is showing.
    expect(find.text('Главная'), findsWidgets);
  });

  testWidgets('no counter demo remains', (tester) async {
    await tester.pumpWidget(await wrapForTest(const NovaApp()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('0'), findsNothing);
  });
}
