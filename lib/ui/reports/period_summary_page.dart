import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../state/analytics.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'report_data.dart';

/// Money in, out and the closing balance for each day, month or year.
class PeriodSummaryPage extends StatefulWidget {
  const PeriodSummaryPage({super.key});

  @override
  State<PeriodSummaryPage> createState() => _PeriodSummaryPageState();
}

class _PeriodSummaryPageState extends State<PeriodSummaryPage> {
  bool _all = false;
  Grouping _grouping = Grouping.month;

  String _label(DateTime d) => switch (_grouping) {
    Grouping.day => Fmt.day(d),
    Grouping.month => Fmt.month(d),
    Grouping.year => '${d.year}',
  };

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: AllDataBuilder(
        builder: (context, data) {
          final entries = data.of(_all ? null : ledger.current?.id);
          final buckets = Analytics.group(entries, _grouping, _label);
          final tot = Totals.of(entries);
          return PageBody(
            children: [
              ScopePicker(allAccounts: _all, onChanged: (v) => setState(() => _all = v)),
              const SizedBox(height: 12),
              SegmentedButton<Grouping>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: Grouping.day, label: Text('Daily')),
                  ButtonSegment(value: Grouping.month, label: Text('Monthly')),
                  ButtonSegment(value: Grouping.year, label: Text('Yearly')),
                ],
                selected: {_grouping},
                onSelectionChanged: (s) => setState(() => _grouping = s.first),
              ),
              const SizedBox(height: 16),
              _TotalsRow(totals: tot),
              const SizedBox(height: 16),
              if (buckets.isEmpty)
                const EmptyState(
                  icon: Icons.calendar_view_month_outlined,
                  title: 'Nothing to summarise yet',
                  message: 'Add some entries and they will be totalled here.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      if (!context.isPhone) const _HeaderRow(),
                      for (var i = 0; i < buckets.length; i++) ...[
                        if (i > 0 || !context.isPhone) Divider(height: 1, color: context.cash.hairline),
                        _BucketRow(bucket: buckets[i]),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final Totals totals;

  const _TotalsRow({required this.totals});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: SectionCard(
            child: StatTile(
              label: 'Cash in',
              value: AmountText(totals.cashIn, isIn: true, style: t.titleLarge),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SectionCard(
            child: StatTile(
              label: 'Cash out',
              value: AmountText(totals.cashOut, isIn: false, style: t.titleLarge),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SectionCard(
            child: StatTile(
              label: 'Balance',
              value: BalanceText(totals.balance, style: t.titleLarge),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).textTheme.labelMedium;
    Widget cell(String v, {int flex = 2, bool end = true}) => Expanded(
      flex: flex,
      child: Text(v, style: s, textAlign: end ? TextAlign.right : TextAlign.left),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          cell('Period', flex: 3, end: false),
          cell('Cash in'),
          cell('Cash out'),
          cell('Net'),
          cell('Closing balance'),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  final Bucket bucket;

  const _BucketRow({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final figures = t.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    if (context.isPhone) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(bucket.label, style: t.titleSmall)),
                Text('${bucket.count} entries', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('In ${Fmt.number(bucket.cashIn)}', style: figures?.copyWith(color: c.inText))),
                Expanded(child: Text('Out ${Fmt.number(bucket.cashOut)}', style: figures?.copyWith(color: c.outText))),
                Expanded(
                  child: Text(
                    'Bal ${Fmt.number(bucket.closing)}',
                    style: figures?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget cell(String v, {Color? color, int flex = 2, FontWeight? w}) => Expanded(
      flex: flex,
      child: Text(v, style: figures?.copyWith(color: color, fontWeight: w), textAlign: TextAlign.right),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(bucket.label, style: t.bodyMedium)),
          cell(Fmt.number(bucket.cashIn), color: c.inText),
          cell(Fmt.number(bucket.cashOut), color: c.outText),
          cell(Fmt.money(bucket.net), color: bucket.net < 0 ? c.outText : null),
          cell(Fmt.money(bucket.closing), w: FontWeight.w600),
        ],
      ),
    );
  }
}
