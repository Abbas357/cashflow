import 'package:cash_flow/app.dart';
import 'package:cash_flow/core/routing/app_router.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/services/cloud_sync.dart';
import 'package:cash_flow/state/ledger_controller.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'routing_test.dart' show settle;

/// Signed out, with Google's part replaced by an instant sign-in.
class _Cloud extends CloudSync {
  _Cloud(super.ledger, super.settings, {this.signed = false});

  bool signed;
  int signIns = 0;

  @override
  bool get available => true;
  @override
  bool get signedIn => signed;
  @override
  String? get email => 'ali@example.com';
  @override
  String get name => 'Ali';

  @override
  Future<void> signIn() async {
    signIns++;
    signed = true;
    notifyListeners();
  }
}

Future<(SettingsController, _Cloud?)> pumpFresh(
  WidgetTester tester, {
  Map<String, Object> prefs = const {'theme_mode': 'light'},
  String location = Routes.home,
  bool withCloud = false,
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final (settings, ledger) = (await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(prefs);
    final s = SettingsController(await SharedPreferences.getInstance());
    final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    final l = LedgerController(LedgerRepository(db, Actor(s.userId, s.displayName)), s);
    await l.load();
    return (s, l);
  }))!;
  addTearDown(() => tester.runAsync(() => ledger.repo.db.close()));

  final cloud = withCloud ? _Cloud(ledger, settings, signed: signedIn) : null;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: ledger),
        if (cloud != null) ChangeNotifierProvider<CloudSync>.value(value: cloud),
      ],
      child: CashFlowApp(initialLocation: location),
    ),
  );
  await settle(tester);
  return (settings, cloud);
}

final welcome = find.text('Welcome to Cash Flow');
final google = find.text('Continue with Google');
final offline = find.text('Continue offline');

void main() {
  sqfliteFfiInit();

  testWidgets('first open: shown, and not closed by tapping outside', (tester) async {
    await pumpFresh(tester, withCloud: true);
    expect(welcome, findsOneWidget);
    expect(google, findsOneWidget);
    expect(offline, findsOneWidget);
    expect(find.text('Google can be connected later via side menu'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(welcome, findsOneWidget);
  });

  testWidgets('the privacy policy opens over the popup, and the popup stays', (tester) async {
    await pumpFresh(tester);
    final link = find.text('Privacy policy');
    await tester.ensureVisible(link);
    await settle(tester);
    await tester.tap(link);
    await settle(tester);
    expect(find.text('The short version'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(welcome, findsOneWidget);
  });

  testWidgets('name is required; address and Google are not', (tester) async {
    final (settings, _) = await pumpFresh(tester, withCloud: true);

    await tester.tap(offline);
    await settle(tester);
    expect(welcome, findsOneWidget);
    expect(find.text('Enter your name'), findsOneWidget);
    expect(settings.onboarded, isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name or business name'), '  Ali  ');
    await settle(tester);
    expect(find.text('Enter your name'), findsNothing);

    await tester.ensureVisible(offline);
    await tester.tap(offline);
    await settle(tester);
    expect(welcome, findsNothing);
    expect(settings.name, 'Ali');
    expect(settings.address, '');
    expect(settings.onboarded, isTrue);
  });

  testWidgets('a cleared currency is refused until one is picked', (tester) async {
    final (settings, _) = await pumpFresh(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name or business name'), 'Ali');

    final field = find.descendant(of: find.byType(DropdownMenu<String>), matching: find.byType(TextField));
    await tester.enterText(field, '');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Choose a currency'), findsOneWidget);
    expect(welcome, findsOneWidget);
    expect(settings.onboarded, isFalse);
  });

  testWidgets('the currency showing is kept, along with the address', (tester) async {
    final (settings, _) = await pumpFresh(tester);
    final shown = settings.currencyInfo.code;
    await tester.enterText(find.widgetWithText(TextFormField, 'Name or business name'), 'Ali');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address (optional)'), 'Peshawar');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(welcome, findsNothing);
    expect(settings.address, 'Peshawar');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('currency_code'), shown);
  });

  testWidgets('Google needs the name too, saves it, and closes once signed in', (tester) async {
    final (settings, cloud) = await pumpFresh(tester, withCloud: true);

    await tester.ensureVisible(google);
    await tester.tap(google);
    await settle(tester);
    expect(cloud!.signIns, 0);
    expect(welcome, findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name or business name'), 'Ali Khan');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await settle(tester);
    expect(cloud.signIns, 1);
    expect(welcome, findsNothing);
    expect(settings.name, 'Ali Khan');
    expect(settings.onboarded, isTrue);
  });

  testWidgets('without cloud sign-in: no Google button, and a plain Continue', (tester) async {
    await pumpFresh(tester);
    expect(welcome, findsOneWidget);
    expect(google, findsNothing);
    expect(offline, findsNothing);
    expect(find.text('Google can be connected later via side menu'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('not shown after the first time', (tester) async {
    await pumpFresh(tester, prefs: {'theme_mode': 'light', 'onboarded': true});
    expect(welcome, findsNothing);
  });

  testWidgets('not shown to someone signed in, or again after signing out', (tester) async {
    final (settings, _) = await pumpFresh(tester, withCloud: true, signedIn: true);
    expect(welcome, findsNothing);
    expect(settings.onboarded, isTrue);
  });

  testWidgets('not shown to someone who already has a name', (tester) async {
    final (settings, _) = await pumpFresh(tester, prefs: {'theme_mode': 'light', 'profile_name': 'Ali'});
    expect(welcome, findsNothing);
    expect(settings.onboarded, isTrue);
  });

  testWidgets('a link to another page is not interrupted', (tester) async {
    final (settings, _) = await pumpFresh(tester, location: Routes.insights);
    expect(welcome, findsNothing);
    expect(settings.onboarded, isFalse);
  });
}
