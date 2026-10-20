import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/cloud_config.dart';
import 'core/theme/app_theme.dart';
import 'data/db/app_database.dart';
import 'data/repositories/ledger_repository.dart';
import 'services/cloud_sync.dart';
import 'services/notifier.dart';
import 'services/push.dart';
import 'state/ledger_controller.dart';
import 'state/settings_controller.dart';
import 'ui/navigation/app_menu.dart';

/// One step of starting up, and how far along the bar it takes us.
class _Step {
  final String label;
  final double done;
  const _Step(this.label, this.done);
}

const _settings = _Step('Reading settings', 0.25);
const _dates = _Step('Preparing dates', 0.35);
const _signIn = _Step('Checking sign-in', 0.45);
const _database = _Step('Opening your books', 0.65);
const _accounts = _Step('Loading accounts', 0.9);

/// Starts the app behind a loading screen: the icon and a progress bar that
/// moves as each step finishes. If a step fails, it says which, shows the
/// error, and offers to try again, instead of hanging on the launch logo.
///
/// On the web, the page's own loading screen (web/index.html) has the same
/// layout and hands over to this one where it left off, so the bar carries
/// on without a jump.
class BootApp extends StatefulWidget {
  /// Whether to connect to the cloud project. Off in tests, which have no
  /// network or plugins.
  final bool cloud;

  const BootApp({super.key, this.cloud = true});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  /// Where the web page's bar stood when Flutter took over.
  static const _webStart = 0.85;

  double _progress = kIsWeb ? _webStart : 0.05;
  _Step? _step;
  bool _slow = false;
  Timer? _slowTimer;
  Object? _error;
  StackTrace? _stack;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  /// Marks [step] as under way. If it takes a while, its name appears
  /// under the bar, so a slow phone shows what it is waiting on.
  void _begin(_Step step) {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });
    setState(() {
      _step = step;
      _slow = false;
    });
  }

  void _finish(_Step step) {
    // The web page already showed the first stretch; share out the rest.
    final share = kIsWeb ? _webStart + (1 - _webStart) * step.done : step.done;
    setState(() => _progress = share);
  }

  Future<T> _run<T>(_Step step, Future<T> Function() work) async {
    _begin(step);
    final result = await work();
    _finish(step);
    return result;
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _stack = null;
    });
    try {
      final prefs = await _run(_settings, SharedPreferences.getInstance);
      final settings = SettingsController(prefs);
      await _run(_dates, () => initializeDateFormatting('en'));
      // Reads the saved session (no network), or on the web finishes a
      // Google sign-in the page was just sent back from.
      if (widget.cloud) {
        await Push.initialize();
        unawaited(Notifier.prepare());
      }
      if (widget.cloud && CloudConfig.enabled) {
        await _run(
          _signIn,
          () => Supabase.initialize(
            url: CloudConfig.url,
            publishableKey: CloudConfig.publishableKey,
            // Desktop apps never get a sign-in link back.
            authOptions: FlutterAuthClientOptions(detectSessionInUri: CloudConfig.signInSupported),
          ),
        );
      }
      final db = await _run(_database, AppDatabase.open);
      final repo = LedgerRepository(db, Actor(settings.userId, settings.displayName));
      final ledger = LedgerController(repo, settings);
      await _run(_accounts, ledger.load);
      _slowTimer?.cancel();
      final cloud = CloudSync(ledger, settings);
      // In the background: the books are usable straight away, offline.
      if (widget.cloud) unawaited(cloud.start());

      setState(() {
        _progress = 1;
        _step = null;
      });
      // Let the bar reach the end before the app fades in.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _app = MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: ledger),
            ChangeNotifierProvider.value(value: cloud),
          ],
          child: const CashFlowApp(),
        );
      });
    } catch (error, stack) {
      _slowTimer?.cancel();
      // Also to the device log (adb logcat), for a closer look.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'cash_flow startup',
          context: ErrorDescription('while ${_step?.label.toLowerCase() ?? 'starting'}'),
        ),
      );
      if (mounted) {
        setState(() {
          _error = error;
          _stack = stack;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _app ??
            _BootShell(
              key: const ValueKey('boot'),
              child: _error == null
                  ? _Loading(progress: _progress, waitingOn: _slow ? _step?.label : null)
                  : _Failed(
                      step: _step?.label,
                      error: _error!,
                      stack: _stack,
                      onRetry: _start,
                    ),
            ),
      ),
    );
  }
}

/// What the startup screen needs from an app (theme, localizations, a place
/// for messages) without being one. A MaterialApp here would bring its own
/// Navigator, which tells the browser it is at `/` on its first frame,
/// overwriting the address (say `/insights` or `/account/<uuid>`) before
/// the real app's router can read it. Only that router may touch the address.
class _BootShell extends StatelessWidget {
  final Widget child;

  const _BootShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Theme(
        data: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        child: ScaffoldMessenger(child: child),
      ),
    );
  }
}

/// The icon with a progress bar under it. Same sizes and spacing as the web
/// page's loading screen: a 96 px icon, a 28 px gap, a 140 x 4 px bar.
class _Loading extends StatelessWidget {
  final double progress;
  final String? waitingOn;

  const _Loading({required this.progress, this.waitingOn});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? const Color(0xFF26302B) : const Color(0xFFDCE5E0);
    final fill = Theme.of(context).colorScheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 96),
            const SizedBox(height: 28),
            Semantics(
              label: 'Loading Cash Flow',
              value: '${(progress * 100).round()}%',
              child: Container(
                width: 140,
                height: 4,
                decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(2)),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (_, value, _) => FractionallySizedBox(
                    widthFactor: value.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            // Takes no room until a step is slow, so the layout matches
            // the web page's exactly.
            SizedBox(
              height: 0,
              child: OverflowBox(
                maxHeight: 60,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  opacity: waitingOn == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      waitingOn == null ? '' : '$waitingOn…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What went wrong while starting, and a way to try again or share details.
class _Failed extends StatelessWidget {
  final String? step;
  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  const _Failed({required this.step, required this.error, required this.stack, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final details = 'Cash Flow could not start'
        '${step == null ? '' : ' while ${step!.toLowerCase()}'}.\n\n$error\n\n$stack';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: BrandMark(size: 72)),
                const SizedBox(height: 20),
                Text('Cash Flow could not start', style: t.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  step == null ? 'Something went wrong while starting.' : 'Something went wrong while ${step!.toLowerCase()}.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Text(
                    '$error',
                    style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Details copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
