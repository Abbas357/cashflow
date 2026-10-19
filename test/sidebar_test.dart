import 'package:cash_flow/core/routing/app_router.dart';
import 'package:cash_flow/ui/navigation/app_shell.dart';
import 'package:cash_flow/ui/reports/insights_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'routing_test.dart' show pumpApp, settle, location;

double sidebarWidth(WidgetTester tester) => tester.getSize(find.byType(AppSidebar)).width;

Finder inSidebar(String text) => find.descendant(of: find.byType(AppSidebar), matching: find.text(text));

Finder get edge => find.byTooltip('Drag to resize, double-click to reset');

/// Windows stands in for desktop and web here; both get the sidebar.
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  sqfliteFfiInit();
  setUp(() => SharedPreferences.setMockInitialValues({'theme_mode': 'light'}));

  group('desktop and web sidebar', () {
    testWidgets('stays beside every page; the current page is marked', (tester) async {
      await pumpApp(tester, Routes.home);
      await tester.tap(inSidebar('Insights'));
      await settle(tester);
      expect(find.byType(InsightsPage), findsOneWidget);
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(location(tester).path, Routes.insights);
    }, variant: desktop);

    testWidgets('folds to a rail and back, by button and Ctrl+B', (tester) async {
      await pumpApp(tester, Routes.home);
      expect(sidebarWidth(tester), 272);

      await tester.tap(find.byTooltip('Close sidebar (Ctrl+B)'));
      await settle(tester);
      expect(sidebarWidth(tester), 60);
      expect(inSidebar('Account summary'), findsNothing);
      expect(find.byTooltip('Account summary'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(sidebarWidth(tester), 272);
      expect(inSidebar('Account summary'), findsOneWidget);
    }, variant: desktop);

    testWidgets('drag the edge to resize; very narrow snaps to the rail; double-click resets', (tester) async {
      await pumpApp(tester, Routes.home);

      await tester.drag(edge, const Offset(80, 0));
      await settle(tester);
      expect(sidebarWidth(tester), closeTo(352, 2));

      await tester.drag(edge, const Offset(400, 0));
      await settle(tester);
      expect(sidebarWidth(tester), 420); // capped

      await tester.drag(edge, const Offset(-320, 0));
      await settle(tester);
      expect(sidebarWidth(tester), 60); // snapped to the rail

      await tester.tap(edge);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(edge);
      await settle(tester);
      expect(sidebarWidth(tester), 272);
    }, variant: desktop);

    testWidgets('width and folded state are remembered', (tester) async {
      await pumpApp(tester, Routes.home);
      await tester.drag(edge, const Offset(60, 0));
      await settle(tester);
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(prefs.getDouble('sidebar_width'), closeTo(332, 2));
      expect(prefs.getBool('sidebar_collapsed'), isFalse);
    }, variant: desktop);

    testWidgets('Ctrl+K searches the menu; Enter opens the match', (tester) async {
      await pumpApp(tester, Routes.home);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.text('Search pages, accounts and actions'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'export');
      await settle(tester);
      // Found by keyword: "export" belongs to Reports and Backup.
      expect(find.text('Reports: all accounts'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(location(tester).path, Routes.reports);
    }, variant: desktop);
  });

  testWidgets('phones get menu search in the drawer, and no sidebar', (tester) async {
    await pumpApp(tester, Routes.home, size: const Size(412, 900));
    expect(find.byType(AppSidebar), findsNothing);
    await tester.tap(find.byTooltip('Menu'));
    await settle(tester);
    await tester.tap(find.byTooltip('Search menu'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'activ');
    await settle(tester);
    await tester.tap(find.text('Activity log'));
    await settle(tester);
    expect(location(tester).path, Routes.activity);
  });

  testWidgets('Android tablets keep a fixed menu without resize or fold', (tester) async {
    await pumpApp(tester, Routes.home);
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.byTooltip('Close sidebar (Ctrl+B)'), findsNothing);
    expect(find.byTooltip('Search menu'), findsOneWidget);
  });
}
