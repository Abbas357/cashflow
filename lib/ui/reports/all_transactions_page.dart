import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../../state/period.dart';
import '../entry/entry_details.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';
import 'report_data.dart';

/// Every entry from every account in one list, newest first.
class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  PeriodKind _kind = PeriodKind.monthly;
  DateTime _anchor = DateTime.now();
  String _query = '';
  EntryType? _type;

  Period get _period => Period(kind: _kind, anchor: _anchor);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('All transactions')),
      body: AllDataBuilder(
        builder: (context, data) {
          final byId = data.byId;
          final q = _query.trim().toLowerCase();
          final list = data.entries.reversed.where((e) {
            if (!_period.contains(e.occurredAt)) return false;
            if (_type != null && e.type != _type) return false;
            if (q.isEmpty) return true;
            return e.note.toLowerCase().contains(q) ||
                (byId[e.accountId]?.name.toLowerCase().contains(q) ?? false);
          }).toList();
          final tot = Totals.of(list);

          return Column(
            children: [
              MaxWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search notes or account',
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final k in [
                              PeriodKind.all,
                              PeriodKind.daily,
                              PeriodKind.weekly,
                              PeriodKind.monthly,
                              PeriodKind.yearly,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(k.label),
                                  selected: _kind == k,
                                  onSelected: (_) => setState(() {
                                    _kind = k;
                                    _anchor = DateTime.now();
                                  }),
                                ),
                              ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('In only'),
                              selected: _type == EntryType.cashIn,
                              onSelected: (v) => setState(() => _type = v ? EntryType.cashIn : null),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Out only'),
                              selected: _type == EntryType.cashOut,
                              onSelected: (v) => setState(() => _type = v ? EntryType.cashOut : null),
                            ),
                          ],
                        ),
                      ),
                      if (_period.canStep)
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: () => setState(() => _anchor = _period.step(-1).anchor),
                            ),
                            Expanded(
                              child: Text(_period.label, style: t.titleSmall, textAlign: TextAlign.center),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: () => setState(() => _anchor = _period.step(1).anchor),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        message: 'Nothing matches this period and filter.',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: context.isPhone ? 12 : 24, vertical: 4),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final e = list[i];
                          return MaxWidth(
                            maxWidth: 900,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: EntryTile(
                                entry: e,
                                showDate: true,
                                accountName: byId[e.accountId]?.name,
                                onTap: () => showEntryDetails(context, e, readOnly: true),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: context.cash.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: MaxWidth(
                      maxWidth: 900,
                      child: Row(
                        children: [
                          Expanded(
                            child: StatTile(label: 'Cash in', value: AmountText(tot.cashIn, isIn: true)),
                          ),
                          Expanded(
                            child: StatTile(label: 'Cash out', value: AmountText(tot.cashOut, isIn: false)),
                          ),
                          Expanded(
                            child: StatTile(label: 'Net', value: BalanceText(tot.balance)),
                          ),
                          Text('${Fmt.number(tot.count)} entries', style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
