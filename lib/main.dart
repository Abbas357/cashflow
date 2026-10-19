import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'boot.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths (/insights) instead of /#/insights on the web.
  usePathUrlStrategy();
  // Draw straight away: settings, the database and accounts load behind a
  // loading screen, which shows any startup failure instead of hanging.
  runApp(const BootApp());
}
