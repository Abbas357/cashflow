import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../navigation/app_menu.dart';
import '../reports/report_actions.dart';
import '../settings/profile_page.dart';
import '../widgets/common.dart';
import 'widgets/account_switcher.dart';
import 'widgets/cash_bar.dart';
import 'widgets/entry_list.dart';
import 'widgets/period_bar.dart';
import 'widgets/summary_panel.dart';

/// The main screen: one account's entries, newest first.
///
/// Phone: drawer menu, list, big Cash In / Cash Out buttons at the bottom.
/// Desktop: the shell's sidebar sits on the left and, when there is room,
/// a summary panel on the right.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The menu itself lives in AppShell: a sidebar on desktop and web, a
    // drawer (opened from here) on phones.
    return LayoutBuilder(
      builder: (context, box) {
        final phone = MediaQuery.sizeOf(context).width < Breakpoints.desktop;
        if (phone) return const _Ledger(showMenuButton: true);
        if (box.maxWidth < Breakpoints.wide - 300) return const _Ledger(showMenuButton: false);
        return Row(
          children: [
            const Expanded(child: _Ledger(showMenuButton: false)),
            VerticalDivider(width: 1, color: Theme.of(context).dividerTheme.color),
            const SizedBox(width: 360, child: SummaryPanel()),
          ],
        );
      },
    );
  }
}

class _Ledger extends StatefulWidget {
  final bool showMenuButton;

  const _Ledger({required this.showMenuButton});

  @override
  State<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends State<_Ledger> {
  late bool _searching;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // A search restored from the address shows its box straight away.
    final restored = context.read<LedgerController>().search;
    _searching = restored.isNotEmpty;
    _search = TextEditingController(text: restored);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _closeSearch(LedgerController ledger) {
    _search.clear();
    ledger.setSearch('');
    setState(() => _searching = false);
  }

  void _newEntry(EntryType type) {
    final ledger = context.read<LedgerController>();
    if (!ledger.canEdit) {
      toast(context, 'You can only view this account.');
      return;
    }
    // A real address (/cash-in, /cash-out), so a refresh reopens the form.
    context.go(Routes.withQuery(Routes.newEntry(type, ledger.current!.id), ledger.viewQuery));
  }

  Future<void> _pickRange(LedgerController ledger) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: ledger.period.range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (r != null) ledger.setRange(r);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final settings = context.watch<SettingsController>();
    final dark = settings.isDark(context);

    final appBar = AppBar(
      automaticallyImplyLeading: false,
      leading: widget.showMenuButton
          ? Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      titleSpacing: widget.showMenuButton ? 0 : 20,
      title: _searching
          ? TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search notes or amounts',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: ledger.setSearch,
            )
          : const AccountTitle(),
      actions: [
        if (_searching)
          IconButton(
            tooltip: 'Close search',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _closeSearch(ledger),
          )
        else ...[
          IconButton(
            tooltip: dark ? 'Light mode' : 'Dark mode',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => settings.toggleDark(context),
          ),
          if (!context.isPhone)
            IconButton(
              tooltip: 'Account report',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => ReportActions.accountReport(context),
            ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() => _searching = true),
          ),
        ],
        _MoreMenu(onPickRange: () => _pickRange(ledger)),
        const SizedBox(width: 4),
      ],
    );

    final body = ledger.loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              PeriodBar(onPickRange: () => _pickRange(ledger)),
              const Expanded(child: EntryList()),
              CashBar(
                onCashIn: () => _newEntry(EntryType.cashIn),
                onCashOut: () => _newEntry(EntryType.cashOut),
              ),
            ],
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _newEntry(EntryType.cashIn),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            _newEntry(EntryType.cashOut),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            setState(() => _searching = true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: appBar,
          drawer: widget.showMenuButton ? const AppMenu() : null,
          body: body,
        ),
      ),
    );
  }
}

enum _MenuAction {
  report,
  sortNotes,
  sortDate,
  range,
  ascending,
  descending,
  print,
  backup,
  profile,
}

/// The three-dot menu: sorting, date range, print, backup and profile.
class _MoreMenu extends StatelessWidget {
  final VoidCallback onPickRange;

  const _MoreMenu({required this.onPickRange});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    PopupMenuItem<_MenuAction> item(_MenuAction a, IconData icon, String label) =>
        PopupMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        );
    CheckedPopupMenuItem<_MenuAction> check(
      _MenuAction a,
      String label,
      bool on,
    ) => CheckedPopupMenuItem(value: a, checked: on, child: Text(label));

    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      position: PopupMenuPosition.under,
      onSelected: (a) {
        switch (a) {
          case _MenuAction.report:
            ReportActions.accountReport(context);
          case _MenuAction.sortNotes:
            ledger.setSort(SortField.notes, ascending: true);
          case _MenuAction.sortDate:
            ledger.setSort(SortField.date, ascending: false);
          case _MenuAction.range:
            onPickRange();
          case _MenuAction.ascending:
            ledger.setAscending(true);
          case _MenuAction.descending:
            ledger.setAscending(false);
          case _MenuAction.print:
            ReportActions.printAccount(context);
          case _MenuAction.backup:
            context.go(Routes.backup);
          case _MenuAction.profile:
            openAdaptive(context, const ProfilePage(), height: 560);
        }
      },
      itemBuilder: (_) => [
        if (context.isPhone) ...[
          item(_MenuAction.report, Icons.picture_as_pdf_outlined, 'Account report (PDF)'),
          const PopupMenuDivider(),
        ],
        check(_MenuAction.sortNotes, 'Sort by notes', ledger.sortField == SortField.notes),
        check(_MenuAction.sortDate, 'Sort by date', ledger.sortField == SortField.date),
        const PopupMenuDivider(),
        item(_MenuAction.range, Icons.date_range_outlined, 'Select date range'),
        check(_MenuAction.ascending, 'Ascending', ledger.ascending),
        check(_MenuAction.descending, 'Descending', !ledger.ascending),
        const PopupMenuDivider(),
        item(_MenuAction.print, Icons.print_outlined, 'Print'),
        item(_MenuAction.backup, Icons.cloud_sync_outlined, 'Backup and restore'),
        item(_MenuAction.profile, Icons.badge_outlined, 'Your name and address'),
      ],
    );
  }
}
