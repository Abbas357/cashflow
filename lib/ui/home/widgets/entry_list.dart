import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/models.dart';
import '../../../state/ledger_controller.dart';
import '../../entry/entry_details.dart';
import '../../widgets/common.dart';
import '../../widgets/entry_tile.dart';

/// The open account's entries in the chosen period. Grouped into one card
/// per day when sorted by date; a single list when sorted by notes.
class EntryList extends StatelessWidget {
  const EntryList({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final entries = ledger.visible;

    if (entries.isEmpty) {
      final searching = ledger.search.trim().isNotEmpty;
      return EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.receipt_long_outlined,
        title: searching ? 'Nothing found' : 'No entries here yet',
        message: searching
            ? 'No entry matches "${ledger.search.trim()}" in this period.'
            : ledger.canEdit
            ? 'Tap Cash In or Cash Out below to record your first entry.'
            : 'Entries added by the account owner will show up here.',
      );
    }

    void open(Entry e) => showEntryDetails(context, e);

    final pad = EdgeInsets.fromLTRB(
      context.isPhone ? 12 : 20,
      4,
      context.isPhone ? 12 : 20,
      16,
    );

    if (ledger.sortField == SortField.notes) {
      return ListView(
        padding: pad,
        children: [
          MaxWidth(
            maxWidth: 900,
            child: _GroupCard(
              children: [
                for (final e in entries)
                  EntryTile(
                    entry: e,
                    showDate: true,
                    balance: ledger.runningBalance(e.id),
                    onTap: () => open(e),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final days = <DateTime, List<Entry>>{};
    for (final e in entries) {
      final d = DateTime(e.occurredAt.year, e.occurredAt.month, e.occurredAt.day);
      (days[d] ??= []).add(e);
    }
    final keys = days.keys.toList();

    return ListView.builder(
      padding: pad,
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final day = keys[i];
        final list = days[day]!;
        final tot = Totals.of(list);
        return MaxWidth(
          maxWidth: 900,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayHeader(day: day, totals: tot),
                _GroupCard(
                  children: [
                    for (final e in list)
                      EntryTile(
                        entry: e,
                        balance: ledger.runningBalance(e.id),
                        onTap: () => open(e),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final Totals totals;

  const _DayHeader({required this.day, required this.totals});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final small = t.labelMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Fmt.relativeDay(day),
              style: t.titleSmall?.copyWith(color: c.muted),
            ),
          ),
          if (totals.cashIn > 0)
            Text('In ${Fmt.number(totals.cashIn)}', style: small?.copyWith(color: c.inText)),
          if (totals.cashIn > 0 && totals.cashOut > 0) const SizedBox(width: 10),
          if (totals.cashOut > 0)
            Text('Out ${Fmt.number(totals.cashOut)}', style: small?.copyWith(color: c.outText)),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;

  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final hairline = context.cash.hairline;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 70, color: hairline),
            children[i],
          ],
        ],
      ),
    );
  }
}
