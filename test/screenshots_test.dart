// Renders key screens to PNG for a visual check.
//
//   flutter test test/screenshots_test.dart --dart-define=SHOTS=<dir>
//
// Skipped unless SHOTS is set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cash_flow/app.dart';
import 'package:cash_flow/core/theme/app_theme.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/models/models.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/state/ledger_controller.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:cash_flow/ui/reports/insights_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _out = String.fromEnvironment('SHOTS');
const _fonts = String.fromEnvironment('FONTS', defaultValue: 'E:/dev/flutter/bin/cache/artifacts/material_fonts');

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$_fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const roboto = ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'];
  await load('Roboto', roboto);
  // Text with no family falls back to the test font, which draws boxes.
  await load('FlutterTest', roboto);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

Future<(SettingsController, LedgerController)> _seed({bool dark = false}) async {
  SharedPreferences.setMockInitialValues({
    'theme_mode': dark ? 'dark' : 'light',
    'profile_name': 'Abbas Khan',
  });
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
  final repo = LedgerRepository(db, Actor(settings.userId, settings.displayName));
  final flat = await repo.createAccount('Flat Expenditures');
  await repo.createAccount('Construction');
  await repo.createAccount('Home Expenses');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<Entry> add(int daysAgo, int h, int m, EntryType t, double amt, String note) => repo.addEntry(
    accountId: flat.id,
    type: t,
    amount: amt,
    note: note,
    occurredAt: today.subtract(Duration(days: daysAgo)).add(Duration(hours: h, minutes: m)),
  );

  for (var month = 5; month >= 1; month--) {
    final d = month * 30;
    await add(d + 2, 10, 0, EntryType.cashIn, 85000 + month * 1500, 'Salary');
    await add(d, 9, 20, EntryType.cashOut, 2000 + month * 300, 'Chikado');
    await add(d - 3, 19, 0, EntryType.cashOut, 18000, 'Rent');
    await add(d - 6, 13, 10, EntryType.cashOut, 6500 + month * 900, 'Groceries');
    await add(d - 9, 8, 45, EntryType.cashOut, 3200, 'Fare to office');
  }
  await add(18, 10, 0, EntryType.cashIn, 92000, 'Salary');
  await add(16, 19, 0, EntryType.cashOut, 18000, 'Rent');
  await add(3, 9, 22, EntryType.cashOut, 150, 'Fare to office');
  await add(3, 9, 22, EntryType.cashOut, 2000, 'Chikado');
  await add(3, 9, 23, EntryType.cashOut, 130, 'Nashta');
  final milk = await add(3, 19, 30, EntryType.cashOut, 100, 'Milk');
  await add(3, 19, 30, EntryType.cashOut, 30, 'Roti');
  await add(2, 9, 25, EntryType.cashOut, 200, 'Fare to office');
  await add(1, 18, 5, EntryType.cashIn, 5000, 'Freelance payment');
  await add(0, 8, 40, EntryType.cashOut, 250, 'Fare to office');
  await repo.updateEntry(milk.copyWith(amount: 120));

  final ledger = LedgerController(repo, settings);
  await ledger.load();
  await ledger.selectAccount(flat);
  return (settings, ledger);
}

final _frame = GlobalKey();

Widget _app(SettingsController s, LedgerController l, {Widget? home}) => RepaintBoundary(key: _frame, child: MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: s),
    ChangeNotifierProvider.value(value: l),
  ],
  child: home == null
      ? const CashFlowApp()
      : Builder(
          builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: s.themeMode,
            home: home,
          ),
        ),
));

Future<void> _shot(WidgetTester tester, String name) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  final boundary = _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.create(recursive: true);
    await f.writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  sqfliteFfiInit();

  final sizes = {
    'phone': const Size(412, 900),
    'desktop': const Size(1500, 920),
  };

  for (final dark in [false, true]) {
    for (final entry in sizes.entries) {
      final tag = '${entry.key}_${dark ? 'dark' : 'light'}';
      testWidgets('home $tag', (tester) async {
        await _loadFonts();
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (s, l) = (await tester.runAsync(() => _seed(dark: dark)))!;
        await tester.pumpWidget(_app(s, l));
        await _shot(tester, 'home_$tag');
      }, skip: _out.isEmpty);
    }
  }

  testWidgets('insights desktop', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1400, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, l) = (await tester.runAsync(() => _seed()))!;
    await tester.pumpWidget(_app(s, l, home: const InsightsPage()));
    await _shot(tester, 'insights_desktop');
  }, skip: _out.isEmpty);

  testWidgets('insights phone dark', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(412, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, l) = (await tester.runAsync(() => _seed(dark: true)))!;
    await tester.pumpWidget(_app(s, l, home: const InsightsPage()));
    await _shot(tester, 'insights_phone_dark');
  }, skip: _out.isEmpty);
}
