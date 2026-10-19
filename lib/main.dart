import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/ledger_repository.dart';
import 'state/ledger_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final db = await AppDatabase.open();
  final repo = LedgerRepository(db, Actor(settings.userId, settings.displayName));
  final ledger = LedgerController(repo, settings);
  await ledger.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: ledger),
      ],
      child: const CashFlowApp(),
    ),
  );
}
