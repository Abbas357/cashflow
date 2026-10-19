import 'package:cash_flow/app.dart';
import 'package:cash_flow/core/routing/app_router.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/models/models.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/state/ledger_controller.dart';
import 'package:cash_flow/state/period.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:cash_flow/ui/entry/entry_form_page.dart';
import 'package:cash_flow/ui/home/home_page.dart';
import 'package:cash_flow/ui/reports/insights_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// A fresh app on a fresh in-memory database. [prefs] carries over between
/// calls, like a browser's storage across a refresh.
Future<LedgerController> pumpApp(
  WidgetTester tester,
  String location, {
  Map<String, Object>? prefs,
  bool viewer = false,
  Size size = const Size(1500, 920),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final (settings, ledger) = (await tester.runAsync(() async {
    if (prefs != null) SharedPreferences.setMockInitialValues(prefs);
    final s = SettingsController(await SharedPreferences.getInstance());
    final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    final l = LedgerController(LedgerRepository(db, Actor(s.userId, s.displayName)), s);
    await l.load();
    if (viewer) {
      await db.update('accounts', {'role': AccountRole.viewer.name});
      await l.reload();
    }
    await l.applyQuery(Uri.parse(location).queryParameters);
    return (s, l);
  }))!;
  addTearDown(() => tester.runAsync(() => ledger.repo.db.close()));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: ledger),
      ],
      child: CashFlowApp(initialLocation: location),
    ),
  );
  await settle(tester);
  return ledger;
}

Uri location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).routerDelegate.currentConfiguration.uri;

void main() {
  sqfliteFfiInit();
  setUp(() => SharedPreferences.setMockInitialValues({'theme_mode': 'light'}));

  testWidgets('a page address opens that page over the ledger', (tester) async {
    await pumpApp(tester, Routes.insights);
    expect(find.widgetWithText(AppBar, 'Insights'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(Routes.isLedger(location(tester).path), isTrue);
  });

  testWidgets('page changes animate in both directions', (tester) async {
    await pumpApp(tester, Routes.home);
    final router = GoRouter.of(tester.element(find.byType(HomePage)));

    // Midway through opening, the page is still sliding in over home.
    router.go(Routes.insights);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final opening = ModalRoute.of(tester.element(find.byType(InsightsPage)))!;
    expect((opening as TransitionRoute).transitionDuration, greaterThan(Duration.zero));
    expect(opening.animation!.value, inExclusiveRange(0, 1));
    await settle(tester);

    // And closing animates out rather than vanishing.
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(InsightsPage), findsOneWidget);
    expect(opening.animation!.value, inExclusiveRange(0, 1));
    await settle(tester);
    expect(find.byType(InsightsPage), findsNothing);
  });

  testWidgets('unknown addresses go home', (tester) async {
    final ledger = await pumpApp(tester, '/no-such-page');
    expect(find.byType(HomePage), findsOneWidget);
    expect(location(tester).path, Routes.account(ledger.current!.id));
  });

  testWidgets('the ledger view is mirrored into the address', (tester) async {
    final ledger = await pumpApp(tester, Routes.home);
    expect(location(tester).path, Routes.account(ledger.current!.id));

    await tester.tap(find.text('Monthly'));
    await settle(tester);
    expect(location(tester).queryParameters['period'], 'monthly');
    expect(location(tester).queryParameters['date'], isNotNull);
  });

  testWidgets('an address restores the view after a refresh', (tester) async {
    final ledger = await pumpApp(tester, '/?period=yearly&date=2025-03-01&q=milk');
    expect(ledger.period.kind, PeriodKind.yearly);
    expect(ledger.period.anchor.year, 2025);
    expect(ledger.search, 'milk');
    expect(find.text('2025'), findsOneWidget);
    // The search box is open with the restored text.
    expect(find.widgetWithText(TextField, 'milk'), findsOneWidget);
  });

  testWidgets('Cash In and Cash Out are addresses; switching type updates it', (tester) async {
    final ledger = await pumpApp(tester, Routes.home);
    final id = ledger.current!.id;
    await tester.tap(find.text('Cash Out'));
    await settle(tester);
    expect(find.byType(EntryFormPage), findsOneWidget);
    expect(location(tester).path, Routes.newEntry(EntryType.cashOut, id));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash In'));
    await settle(tester);
    expect(location(tester).path, Routes.newEntry(EntryType.cashIn, id));
    expect(find.byType(EntryFormPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.byType(EntryFormPage), findsNothing);
    expect(location(tester).path, Routes.account(id));
  });

  testWidgets('/account/<uuid> opens that account; switching updates the address', (tester) async {
    final ledger = await pumpApp(tester, Routes.home);
    final home = ledger.current!;
    final other = (await tester.runAsync(() => ledger.createAccount('Construction')))!;
    await settle(tester);

    GoRouter.of(tester.element(find.byType(HomePage))).go(Routes.account(other.id));
    await settle(tester);
    expect(ledger.current!.id, other.id);
    expect(find.text('Construction'), findsWidgets);

    await tester.runAsync(() => ledger.selectAccount(home));
    await settle(tester);
    expect(location(tester).path, Routes.account(home.id));
  });

  testWidgets('old ?account= links and unknown accounts land on a real account', (tester) async {
    final ledger = await pumpApp(tester, Routes.home);
    final id = ledger.current!.id;
    final router = GoRouter.of(tester.element(find.byType(HomePage)));

    router.go('/?account=$id&period=monthly');
    await settle(tester);
    expect(location(tester).path, Routes.account(id));
    expect(location(tester).queryParameters['period'], 'monthly');
    expect(location(tester).queryParameters.containsKey('account'), isFalse);

    router.go('${Routes.account('no-such-account')}/cash-in');
    await settle(tester);
    expect(location(tester).path, Routes.newEntry(EntryType.cashIn, id));
  });

  testWidgets('a refresh on /cash-out brings back what was typed', (tester) async {
    await pumpApp(tester, '/account/any/cash-out');
    await tester.enterText(find.byType(TextField).at(0), '450');
    await tester.enterText(find.byType(TextField).at(1), 'Petrol');
    await settle(tester);

    // "Refresh": same storage, new app, same address.
    final stored = (await tester.runAsync(SharedPreferences.getInstance))!;
    final prefs = {for (final k in stored.getKeys()) k: stored.get(k)!};
    expect(prefs['entry_draft'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, '/account/any/cash-out', prefs: prefs);

    expect(find.widgetWithText(TextField, '450'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Petrol'), findsOneWidget);
  });

  testWidgets('closing the form on purpose drops the draft', (tester) async {
    await pumpApp(tester, '/account/any/cash-in');
    await tester.enterText(find.byType(TextField).at(0), '99');
    await settle(tester);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getString('entry_draft'), isNull);
  });

  testWidgets('viewers cannot open /cash-in by address', (tester) async {
    final ledger = await pumpApp(tester, '/account/any/cash-in', viewer: true);
    expect(find.byType(EntryFormPage), findsNothing);
    expect(location(tester).path, Routes.account(ledger.current!.id));
  });

  test('view query round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsController(await SharedPreferences.getInstance());
    final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    addTearDown(db.close);
    final a = LedgerController(LedgerRepository(db, const Actor('u', 'U')), s);
    await a.load();
    a.setRange(DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)));
    a.setSearch('rent');
    a.setSort(SortField.notes, ascending: false);

    final b = LedgerController(LedgerRepository(db, const Actor('u', 'U')), s);
    await b.load();
    await b.applyQuery(a.viewQuery);
    expect(b.viewQuery, a.viewQuery);
    expect(a.viewQuery, containsPair('from', '2026-09-01'));
    expect(a.viewQuery, containsPair('order', 'desc'));
  });
}
