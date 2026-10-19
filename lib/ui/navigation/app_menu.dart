import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/settings_controller.dart';
import '../accounts/accounts_page.dart';
import '../activity/activity_page.dart';
import '../backup/backup_page.dart';
import '../help/help_page.dart';
import '../help/how_to_use_page.dart';
import '../reports/account_summary_page.dart';
import '../reports/all_transactions_page.dart';
import '../reports/insights_page.dart';
import '../reports/period_summary_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../transfer/transfer_page.dart';

class _Item {
  final IconData icon;
  final String label;
  final Widget Function() page;
  final String? badge;
  const _Item(this.icon, this.label, this.page, {this.badge});
}

class _Section {
  final String? title;
  final List<_Item> items;
  const _Section(this.title, this.items);
}

final _sections = <_Section>[
  _Section(null, [
    _Item(Icons.menu_book_outlined, 'How to use the app', () => const HowToUsePage()),
  ]),
  _Section('Reports', [
    _Item(Icons.insights_outlined, 'Insights', () => const InsightsPage(), badge: 'New'),
    _Item(Icons.calendar_view_month_outlined, 'Summary', () => const PeriodSummaryPage()),
    _Item(Icons.account_balance_outlined, 'Account summary', () => const AccountSummaryPage()),
    _Item(Icons.receipt_long_outlined, 'Transactions: all accounts', () => const AllTransactionsPage()),
    _Item(Icons.picture_as_pdf_outlined, 'Reports: all accounts', () => const ReportsPage()),
    _Item(Icons.history_rounded, 'Activity log', () => const ActivityPage()),
  ]),
  _Section('Manage', [
    _Item(Icons.folder_shared_outlined, 'Accounts', () => const AccountsPage()),
    _Item(Icons.swap_horiz_rounded, 'Transfer', () => const TransferPage()),
    _Item(Icons.cloud_sync_outlined, 'Backup and restore', () => const BackupPage()),
  ]),
  _Section('App', [
    _Item(Icons.settings_outlined, 'Settings', () => const SettingsPage()),
    _Item(Icons.help_outline_rounded, 'Help and about', () => const HelpPage()),
  ]),
];

/// The app's main menu. A modal drawer on phones, a fixed side panel on
/// desktop.
class AppMenu extends StatelessWidget {
  final bool permanent;

  const AppMenu({super.key, this.permanent = false});

  void _open(BuildContext context, _Item item) {
    if (!permanent) Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.page()));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash Flow', style: t.titleLarge),
                    Text(
                      settings.name.isEmpty
                          ? 'Offline, saved on this device'
                          : settings.name,
                      style: t.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final section in _sections) ...[
          if (section.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                section.title!.toUpperCase(),
                style: t.labelSmall?.copyWith(letterSpacing: 1.1),
              ),
            ),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(item.icon, size: 22),
                title: Text(item.label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                trailing: item.badge == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.badge!,
                          style: t.labelSmall?.copyWith(color: scheme.primary),
                        ),
                      ),
                onTap: () => _open(context, item),
              ),
            ),
        ],
      ],
    );

    if (permanent) {
      return Material(color: scheme.surface, child: SafeArea(child: list));
    }
    return Drawer(width: 304, child: SafeArea(child: list));
  }
}
