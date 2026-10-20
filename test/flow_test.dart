import 'package:cash_flow/app.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/state/ledger_controller.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:cash_flow/ui/entry/entry_details.dart';
import 'package:cash_flow/ui/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lets real database work finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();

  for (final size in const [Size(412, 900), Size(1500, 920)]) {
    testWidgets('add an entry, edit it, see the old value (${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final (settings, ledger) = (await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'light', 'profile_name': 'Ali', 'currency_code': 'PKR'});
        final s = SettingsController(await SharedPreferences.getInstance());
        final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
        final l = LedgerController(LedgerRepository(db, Actor(s.userId, s.displayName)), s);
        await l.load();
        return (s, l);
      }))!;
      // sqflite reuses an open in-memory database by path; close it so the
      // next test starts empty.
      addTearDown(() => tester.runAsync(() => ledger.repo.db.close()));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: ledger),
          ],
          child: const CashFlowApp(),
        ),
      );
      await settle(tester);
      expect(find.text('Personal'), findsWidgets);
      expect(find.text('No entries here yet'), findsOneWidget);

      // New Cash Out of 100 for Milk.
      await tester.tap(find.text('Cash Out'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), '60+40');
      await tester.enterText(find.byType(TextField).at(1), 'Milk');
      await tester.tap(find.text('Save & exit'));
      await settle(tester);

      expect(ledger.allEntries.single.amount, 100);
      // On desktop the overview panel lists it under top spending too.
      final milkRow = find.descendant(of: find.byType(EntryTile), matching: find.text('Milk'));
      expect(milkRow, findsOneWidget);
      final row = find.byType(EntryTile);
      expect(find.descendant(of: row, matching: find.text('-Rs 100')), findsOneWidget);
      expect(find.text('Rs 100'), findsWidgets);

      // Open it, edit to 120.
      await tester.tap(milkRow);
      await settle(tester);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), '120');
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      expect(ledger.allEntries.single.amount, 120);
      expect(find.descendant(of: row, matching: find.text('-Rs 120')), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);

      // History shows the old value beside the new one.
      await tester.tap(milkRow);
      await settle(tester);
      final sheet = find.byType(EntryDetails);
      expect(find.descendant(of: sheet, matching: find.text('Rs 100')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Rs 120')), findsOneWidget);
      expect(find.textContaining('Edited by Ali'), findsOneWidget);
    });
  }
}
