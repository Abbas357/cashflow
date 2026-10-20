import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/cloud_sync.dart';
import 'services/update_check.dart';
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
  late final SettingsController _settings = context.read<SettingsController>();
  late final CloudSync? _cloud = context.read<CloudSync?>();
  late final GoRouter _router = buildRouter(_ledger, initialLocation: widget.initialLocation);
  bool _mirrorQueued = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _updates = UpdateCheck(_offerReload);

  @override
  void initState() {
    super.initState();
    _updates.start();
    _cloud?.addListener(_offerPendingJoin);
    _ledger.addListener(_queueMirror);
    _router.routerDelegate.addListener(_queueMirror);
    _queueMirror();
  }

  @override
  void dispose() {
    _updates.dispose();
    _cloud?.removeListener(_offerPendingJoin);
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

  /// An invitation code scanned before signing in opens again once they
  /// are signed in (on the web, the Google round trip lands on the start
  /// page and the code would otherwise be lost).
  void _offerPendingJoin() {
    final code = _settings.pendingJoin;
    if (code == null || !(_cloud?.signedIn ?? false)) return;
    _settings.setPendingJoin(null);
    _router.go(Routes.join(code));
  }

  /// A newer build is live: say so until they reload. Nothing typed is
  /// lost, since drafts and entries are saved as they go.
  void _offerReload() {
    _messenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text('A new version of Cash Flow is ready'),
        duration: Duration(days: 1),
        action: SnackBarAction(label: 'Reload', onPressed: UpdateCheck.reload),
      ),
    );
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
      scaffoldMessengerKey: _messenger,
    );
  }
}
