import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';

/// Every account and every live entry, reloaded whenever the ledger
/// changes. Report pages build on this.
class AllData {
  final List<Account> accounts;
  final List<Entry> entries;

  const AllData(this.accounts, this.entries);

  Map<String, Account> get byId => {for (final a in accounts) a.id: a};

  List<Entry> of(String? accountId) =>
      accountId == null ? entries : entries.where((e) => e.accountId == accountId).toList();
}

class AllDataBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, AllData data) builder;

  const AllDataBuilder({super.key, required this.builder});

  @override
  State<AllDataBuilder> createState() => _AllDataBuilderState();
}

class _AllDataBuilderState extends State<AllDataBuilder> {
  AllData? _data;
  int _seen = -1;

  Future<void> _load(LedgerController ledger) async {
    final accounts = await ledger.repo.accounts();
    final entries = await ledger.repo.entries();
    final ids = accounts.map((a) => a.id).toSet();
    if (mounted) {
      setState(() => _data = AllData(accounts, entries.where((e) => ids.contains(e.accountId)).toList()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    if (_seen != ledger.revision) {
      _seen = ledger.revision;
      _load(ledger);
    }
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, d);
  }
}

/// "This account" or "All accounts", used at the top of report pages.
class ScopePicker extends StatelessWidget {
  final bool allAccounts;
  final ValueChanged<bool> onChanged;

  const ScopePicker({super.key, required this.allAccounts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final name = context.watch<LedgerController>().current?.name ?? 'This account';
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: false, label: Text(name, overflow: TextOverflow.ellipsis)),
        const ButtonSegment(value: true, label: Text('All accounts')),
      ],
      selected: {allAccounts},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
