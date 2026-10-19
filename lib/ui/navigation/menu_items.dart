import 'package:flutter/material.dart';

import '../../core/routing/app_router.dart';

/// One place the menu can take you.
class MenuItem {
  final IconData icon;
  final String label;
  final String path;
  final String? badge;

  /// Extra words the menu search matches, beyond the label.
  final String keywords;

  const MenuItem(this.icon, this.label, this.path, {this.badge, this.keywords = ''});

  /// Whether this item is the screen at [location]. Home covers every
  /// account's ledger (`/account/<uuid>`).
  bool isCurrent(String location) =>
      path == Routes.home ? Routes.isLedger(location) : location == path;
}

class MenuSection {
  final String? title;
  final List<MenuItem> items;
  const MenuSection(this.title, this.items);
}

/// The whole menu, shared by the phone drawer and the desktop sidebar.
const menuSections = <MenuSection>[
  MenuSection(null, [
    MenuItem(Icons.home_outlined, 'Home', Routes.home, keywords: 'ledger entries cash book'),
    MenuItem(Icons.menu_book_outlined, 'How to use the app', Routes.howToUse, keywords: 'guide help tutorial'),
  ]),
  MenuSection('Reports', [
    MenuItem(Icons.insights_outlined, 'Insights', Routes.insights, badge: 'New', keywords: 'charts trends spending'),
    MenuItem(Icons.calendar_view_month_outlined, 'Summary', Routes.summary, keywords: 'daily monthly yearly totals'),
    MenuItem(Icons.account_balance_outlined, 'Account summary', Routes.accountSummary, keywords: 'balances'),
    MenuItem(Icons.receipt_long_outlined, 'Transactions: all accounts', Routes.transactions, keywords: 'entries list'),
    MenuItem(Icons.picture_as_pdf_outlined, 'Reports: all accounts', Routes.reports, keywords: 'pdf csv export print'),
    MenuItem(Icons.history_rounded, 'Activity log', Routes.activity, keywords: 'history changes edits'),
  ]),
  MenuSection('Manage', [
    MenuItem(Icons.folder_shared_outlined, 'Accounts', Routes.accounts, keywords: 'share rename delete'),
    MenuItem(Icons.swap_horiz_rounded, 'Transfer', Routes.transfer, keywords: 'move money'),
    MenuItem(Icons.cloud_sync_outlined, 'Backup and restore', Routes.backup, keywords: 'export import file'),
  ]),
  MenuSection('App', [
    MenuItem(Icons.settings_outlined, 'Settings', Routes.settings, keywords: 'currency theme profile'),
    MenuItem(Icons.help_outline_rounded, 'Help and about', Routes.help, keywords: 'faq version'),
  ]),
];

Iterable<MenuItem> get allMenuItems => menuSections.expand((s) => s.items);
