import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
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
  // Real paths (/insights) instead of /#/insights on the web.
  usePathUrlStrategy();
  await initializeDateFormatting('en');

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final db = await AppDatabase.open();
  final repo = LedgerRepository(db, Actor(settings.userId, settings.displayName));
  final ledger = LedgerController(repo, settings);
  // The router puts back the account, period and search from the address
  // (after a browser refresh, for example) before the first frame.
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
