import 'package:cash_flow/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'routing_test.dart' show pumpApp, settle;

void main() {
  sqfliteFfiInit();

  testWidgets('Settings shows what is sent and can delete it', (tester) async {
    await pumpApp(
      tester,
      Routes.settings,
      prefs: {'theme_mode': 'light', 'country_code': 'PK', 'currency_code': 'PKR', 'currency': 'Rs'},
    );

    final delete = find.text('Delete this information');
    await tester.scrollUntilVisible(delete, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    expect(find.text('Random ID'), findsOneWidget);
    expect(find.widgetWithText(Row, 'PK'), findsWidgets);

    // Cancelling keeps everything.
    await tester.tap(delete);
    await settle(tester);
    expect(find.text('Delete this information?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Random ID'), findsOneWidget);

    await tester.tap(delete);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(find.text('Random ID'), findsNothing);
    expect(find.text('This device no longer sends information for counting users per country.'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('install_stats_off'), isTrue);
  });
}
