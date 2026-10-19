import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/ledger_controller.dart';
import 'state/settings_controller.dart';

class CashFlowApp extends StatefulWidget {
  final String initialLocation;

  const CashFlowApp({super.key, this.initialLocation = Routes.home});

  @override
  State<CashFlowApp> createState() => _CashFlowAppState();
}

class _CashFlowAppState extends State<CashFlowApp> {
  late final LedgerController _ledger = context.read<LedgerController>();
  late final GoRouter _router = buildRouter(_ledger, initialLocation: widget.initialLocation);
  bool _mirrorQueued = false;

  @override
  void initState() {
    super.initState();
    _ledger.addListener(_queueMirror);
    _router.routerDelegate.addListener(_queueMirror);
    _queueMirror();
  }

  @override
  void dispose() {
    _ledger.removeListener(_queueMirror);
    _router.routerDelegate.removeListener(_queueMirror);
    _router.dispose();
    super.dispose();
  }

  void _queueMirror() {
    if (_mirrorQueued) return;
    _mirrorQueued = true;
    // After the frame, so the router has finished its own navigation and
    // reported its address before this one replaces it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mirrorQueued = false;
      _mirror();
    });
  }

  /// Keeps the address in step with the ledger: `/account/<uuid>` for the
  /// open account, plus its period and search, on the screens that show
  /// it. Uses replaceState, not pushState, so Back goes to the previous
  /// page rather than stepping through every filter tap or account switch.
  void _mirror() {
    if (!mounted) return;
    final uri = _router.routerDelegate.currentConfiguration.uri;
    final id = _ledger.current?.id;
    if (id == null || !Routes.carriesView(uri.path)) return;
    // Keep a popup (/cash-in, /cash-out) open; swap in the open account.
    final popup = uri.pathSegments.skip(2).map((s) => '/$s').join();
    final want = Routes.withQuery('${Routes.account(id)}$popup', _ledger.viewQuery);
    if (want == uri.toString()) return;
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    Router.neglect(context, () => _router.go(want));
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsController, ThemeMode>((s) => s.themeMode);
    return MaterialApp.router(
      title: 'Cash Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      routerConfig: _router,
    );
  }
}
