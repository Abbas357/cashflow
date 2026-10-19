import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'state/settings_controller.dart';
import 'ui/home/home_page.dart';

class CashFlowApp extends StatelessWidget {
  const CashFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsController, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Cash Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: const HomePage(),
    );
  }
}
