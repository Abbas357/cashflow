import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../state/ledger_controller.dart';
import '../../accounts/sharing_page.dart';
import '../../widgets/common.dart';

/// The app bar title: the open account's name, tap to switch.
class AccountTitle extends StatelessWidget {
  const AccountTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final acc = ledger.current;
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showAccountSwitcher(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    acc?.name ?? 'Cash Flow',
                    style: t.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (acc != null && !acc.canEdit)
                    Text('View only', style: t.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}

Future<void> showAccountSwitcher(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _AccountSwitcher(),
  );
}

class _AccountSwitcher extends StatefulWidget {
  const _AccountSwitcher();

  @override
  State<_AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends State<_AccountSwitcher> {
  String _query = '';
  bool _editing = false;
  Map<String, (double, double, int)> _totals = {};

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    final t = await context.read<LedgerController>().repo.accountTotals();
    if (mounted) setState(() => _totals = t);
  }

  Future<void> _add() async {
    final ledger = context.read<LedgerController>();
    final name = await promptText(context, title: 'New account', action: 'Create');
    if (name == null) return;
    final a = await ledger.createAccount(name);
    await ledger.selectAccount(a);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _rename(Account a) async {
    final ledger = context.read<LedgerController>();
    final name = await promptText(context, title: 'Rename account', initial: a.name);
    if (name != null) await ledger.renameAccount(a, name);
  }

  Future<void> _delete(Account a) async {
    final ledger = context.read<LedgerController>();
    final ok = await confirm(
      context,
      title: 'Delete "${a.name}"?',
      message: 'The account and all of its entries will be removed.',
    );
    if (ok) {
      await ledger.deleteAccount(a);
      await _loadTotals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final list = ledger.accounts
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Accounts', style: t.titleLarge)),
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined, size: 18),
                    label: Text(_editing ? 'Done' : 'Edit'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search accounts',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No accounts match.', textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final a = list[i];
                        final tot = _totals[a.id];
                        final selected = a.id == ledger.current?.id;
                        final balance = tot == null ? 0.0 : tot.$1 - tot.$2;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: selected
                                ? AppTheme.brandColor
                                : scheme.surfaceContainerHighest,
                            foregroundColor: selected ? Colors.white : scheme.onSurface,
                            child: Text(
                              a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(a.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${tot?.$3 ?? 0} entries${a.isShared ? '  ·  Shared' : ''}',
                          ),
                          trailing: _editing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Share',
                                      icon: const Icon(Icons.person_add_alt_outlined),
                                      onPressed: () => openSharing(context, a),
                                    ),
                                    IconButton(
                                      tooltip: 'Rename',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _rename(a),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      color: AppTheme.errorColor,
                                      onPressed: () => _delete(a),
                                    ),
                                  ],
                                )
                              : BalanceText(
                                  balance,
                                  style: t.titleSmall,
                                ),
                          onTap: _editing
                              ? () => _rename(a)
                              : () async {
                                  await ledger.selectAccount(a);
                                  if (context.mounted) Navigator.pop(context);
                                },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
