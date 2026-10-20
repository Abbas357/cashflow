import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'sharing_page.dart';

/// Every account: open, rename, reorder, share or delete.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  Map<String, (double, double, int)> _totals = {};
  int _seen = -1;

  Future<void> _load() async {
    final t = await context.read<LedgerController>().repo.accountTotals();
    if (mounted) setState(() => _totals = t);
  }

  Future<void> _add() async {
    final name = await promptText(context, title: 'New account', action: 'Create');
    if (name != null && mounted) await context.read<LedgerController>().createAccount(name);
  }

  Future<void> _rename(Account a) async {
    final name = await promptText(context, title: 'Rename account', initial: a.name);
    if (name != null && mounted) await context.read<LedgerController>().renameAccount(a, name);
  }

  Future<void> _delete(Account a) async {
    final ok = await confirm(
      context,
      title: 'Delete "${a.name}"?',
      message: 'The account and all of its entries will be removed.',
    );
    if (ok && mounted) await context.read<LedgerController>().deleteAccount(a);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    if (_seen != ledger.revision) {
      _seen = ledger.revision;
      _load();
    }
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
      body: MaxWidth(
        maxWidth: 820,
        child: ReorderableListView.builder(
          padding: EdgeInsets.fromLTRB(context.isPhone ? 16 : 24, 8, context.isPhone ? 16 : 24, 96),
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Drag to reorder. Share an account by email or QR code to let others follow it.',
              style: t.bodySmall,
            ),
          ),
          itemCount: ledger.accounts.length,
          onReorderItem: ledger.reorderAccounts,
          itemBuilder: (context, i) {
            final a = ledger.accounts[i];
            final tot = _totals[a.id];
            final balance = tot == null ? 0.0 : tot.$1 - tot.$2;
            final open = a.id == ledger.current?.id;
            return Padding(
              key: ValueKey(a.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.drag_indicator_rounded),
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: open
                            ? AppTheme.brandColor
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        foregroundColor: open ? Colors.white : null,
                        child: Text(
                          a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  title: Text(a.name, style: t.titleMedium),
                  subtitle: Text(
                    [
                      '${tot?.$3 ?? 0} entries',
                      if (a.isShared) 'Shared',
                      if (open) 'Open now',
                    ].join('  ·  '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!context.isPhone) ...[
                        BalanceText(balance),
                        const SizedBox(width: 8),
                      ],
                      PopupMenuButton<String>(
                        tooltip: 'Options',
                        onSelected: (v) {
                          switch (v) {
                            case 'open':
                              ledger.selectAccount(a);
                              context.go(Routes.home);
                            case 'share':
                              openSharing(context, a);
                            case 'rename':
                              _rename(a);
                            case 'delete':
                              _delete(a);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: Text('Open')),
                          const PopupMenuItem(value: 'share', child: Text('Share')),
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    ledger.selectAccount(a);
                    context.go(Routes.home);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
