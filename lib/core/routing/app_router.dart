import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../../ui/accounts/accounts_page.dart';
import '../../ui/activity/activity_page.dart';
import '../../ui/backup/backup_page.dart';
import '../../ui/entry/entry_form_page.dart';
import '../../ui/help/help_page.dart';
import '../../ui/help/how_to_use_page.dart';
import '../../ui/home/home_page.dart';
import '../../ui/navigation/app_shell.dart';
import '../../ui/reports/account_summary_page.dart';
import '../../ui/reports/all_transactions_page.dart';
import '../../ui/reports/insights_page.dart';
import '../../ui/reports/period_summary_page.dart';
import '../../ui/reports/reports_page.dart';
import '../../ui/settings/settings_page.dart';
import '../../ui/transfer/transfer_page.dart';
import '../utils/responsive.dart';

/// Every screen with its own address. On the web these are real paths
/// (pushState), so refresh, Back and bookmarks land on the same screen.
///
/// The ledger lives at `/account/<uuid>`: the account is what is shown, so
/// it is part of the path; period, date and search are how it is shown, so
/// they ride in the query. `/` opens the current account.
///
/// Only pages and the Cash In / Cash Out popups have addresses. Other
/// popups (entry details, edit, share, confirmations, pickers) are
/// transient and close on refresh.
class Routes {
  Routes._();

  static const home = '/';
  static const cashIn = 'cash-in';
  static const cashOut = 'cash-out';
  static const insights = '/insights';
  static const summary = '/summary';
  static const accountSummary = '/account-summary';
  static const transactions = '/transactions';
  static const reports = '/reports';
  static const activity = '/activity';
  static const accounts = '/accounts';
  static const transfer = '/transfer';
  static const backup = '/backup';
  static const settings = '/settings';
  static const help = '/help';
  static const howToUse = '/how-to-use';

  /// The ledger of the account with [id].
  static String account(String id) => '/account/$id';

  /// The Cash In or Cash Out popup over the account with [accountId].
  static String newEntry(EntryType type, String accountId) =>
      '${account(accountId)}/${type.isIn ? cashIn : cashOut}';

  /// Whether [path] shows the ledger (directly or under a popup), and so
  /// carries the ledger view in its address.
  static bool carriesView(String path) => path == home || path.startsWith('/account/');

  /// Whether [path] is the ledger itself, with no popup over it.
  static bool isLedger(String path) =>
      path == home || (path.startsWith('/account/') && path.split('/').length == 3);

  /// [path] with [query] appended, or [path] alone when [query] is empty.
  static String withQuery(String path, Map<String, String> query) =>
      query.isEmpty ? path : '$path?${Uri(queryParameters: query).query}';
}

/// Opens a page route as a centred dialog, so a popup can have an address
/// and still look like a popup on desktop.
class DialogPage<T> extends Page<T> {
  final Widget child;
  final double width;
  final double height;

  const DialogPage({
    super.key,
    super.name,
    required this.child,
    this.width = 560,
    this.height = 640,
  });

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
    context: context,
    settings: this,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: width,
          height: math.min(height, size.height - 48),
          child: child,
        ),
      );
    },
  );
}

GoRouter buildRouter(
  LedgerController ledger, {
  String initialLocation = Routes.home,
}) {
  // Pages live inside the shell (beside the desktop sidebar). The Cash In /
  // Cash Out popups sit above it on the root navigator, so their backdrop
  // covers the whole window.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Both popups share a key, so switching Cash In <-> Cash Out inside the
  // form updates the address without closing and reopening it.
  const entryKey = ValueKey('new-entry');

  Page<void> entryPage(
    BuildContext context,
    GoRouterState state,
    EntryType type,
  ) {
    final form = EntryFormPage(type: type, routed: true);
    if (context.isPhone) {
      return MaterialPage(key: entryKey, name: state.uri.path, child: form);
    }
    return DialogPage(key: entryKey, name: state.uri.path, child: form);
  }

  // Explicit MaterialPages: go_router's own MaterialApp detection can miss
  // and fall back to pages with no transition. These animate exactly like
  // Navigator.push did, using the theme's page transitions.
  Page<void> material(GoRouterState state, Widget child) =>
      MaterialPage(key: state.pageKey, name: state.uri.path, child: child);

  GoRoute page(String path, Widget Function() build) => GoRoute(
    path: path.substring(1),
    pageBuilder: (_, state) => material(state, build()),
  );

  // The ledger is one page whatever account it shows: a fixed key, so
  // switching accounts updates it in place instead of animating a new page.
  Page<void> ledgerPage(GoRouterState state) =>
      MaterialPage(key: const ValueKey('ledger'), name: state.uri.path, child: const HomePage());

  /// `/` and old `?account=<uuid>` links open the ledger of that account
  /// (or the current one) at its own address.
  String? homeRedirect(GoRouterState state) {
    if (state.uri.path != Routes.home) return null;
    final query = {...state.uri.queryParameters};
    final asked = query.remove('account');
    final id = ledger.accounts.any((a) => a.id == asked) ? asked! : ledger.current?.id;
    return id == null ? null : Routes.withQuery(Routes.account(id), query);
  }

  /// Opening `/account/<uuid>` opens that account. An unknown or deleted
  /// one falls back to the current account, keeping the rest of the address.
  Future<String?> accountRedirect(GoRouterState state) async {
    final id = state.pathParameters['id'];
    final account = ledger.accounts.where((a) => a.id == id).firstOrNull;
    if (account == null) {
      final current = ledger.current;
      if (current == null) return null;
      final rest = state.uri.pathSegments.skip(2).map((s) => '/$s').join();
      return Routes.withQuery('${Routes.account(current.id)}$rest', state.uri.queryParameters);
    }
    if (account.id != ledger.current?.id) await ledger.selectAccount(account);
    // An address that names a period, date or search (a refresh, a
    // bookmark, a shared link) sets the view. A bare one keeps the view.
    final query = state.uri.queryParameters;
    final view = {for (final k in LedgerController.viewKeys) if (query.containsKey(k)) k: query[k]!};
    if (view.isNotEmpty && !mapEquals(view, ledger.viewQuery)) await ledger.applyQuery(query);
    return null;
  }

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    redirect: (_, state) => homeRedirect(state),
    // Unknown addresses go home rather than to an error screen.
    onException: (_, _, router) => router.go(Routes.home),
    routes: [
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, state) => ledgerPage(state),
            routes: [
              page(Routes.insights, () => const InsightsPage()),
              page(Routes.summary, () => const PeriodSummaryPage()),
              page(Routes.accountSummary, () => const AccountSummaryPage()),
              page(Routes.transactions, () => const AllTransactionsPage()),
              page(Routes.reports, () => const ReportsPage()),
              page(Routes.activity, () => const ActivityPage()),
              page(Routes.accounts, () => const AccountsPage()),
              page(Routes.transfer, () => const TransferPage()),
              page(Routes.backup, () => const BackupPage()),
              page(Routes.settings, () => const SettingsPage()),
              page(Routes.help, () => const HelpPage()),
              page(Routes.howToUse, () => const HowToUsePage()),
            ],
          ),
          GoRoute(
            path: '/account/:id',
            redirect: (_, state) => accountRedirect(state),
            pageBuilder: (_, state) => ledgerPage(state),
            routes: [
              for (final type in EntryType.values)
                GoRoute(
                  path: type.isIn ? Routes.cashIn : Routes.cashOut,
                  parentNavigatorKey: rootKey,
                  // Viewers cannot add entries, even by typing the address.
                  redirect: (_, state) => ledger.canEdit
                      ? null
                      : Routes.withQuery(
                          Routes.account(state.pathParameters['id']!),
                          state.uri.queryParameters,
                        ),
                  pageBuilder: (context, state) =>
                      entryPage(context, state, type),
                ),
            ],
          ),
        ],
      ),
    ],
  );
}
