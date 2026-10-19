import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/analytics.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'charts.dart';
import 'report_data.dart';

/// Trends and patterns: where money goes, how the balance moves, and
/// which days cost the most. Replaces the old static reports.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _all = false;
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: AllDataBuilder(
        builder: (context, data) {
          final entries = data.of(_all ? null : ledger.current?.id);
          return PageBody(
            maxWidth: 1100,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ScopePicker(allAccounts: _all, onChanged: (v) => setState(() => _all = v)),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 6, label: Text('6 months')),
                      ButtonSegment(value: 12, label: Text('12 months')),
                    ],
                    selected: {_months},
                    onSelectionChanged: (s) => setState(() => _months = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No data yet',
                  message: 'Insights appear once a few entries are recorded.',
                )
              else
                _Insights(entries: entries, months: _months),
            ],
          );
        },
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final List<Entry> entries;
  final int months;

  const _Insights({required this.entries, required this.months});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final now = DateTime.now();
    final buckets = Analytics.lastMonths(
      entries,
      months,
      (d) => Fmt.monthShort(d).split(' ').first,
    );
    final windowStart = buckets.first.start;
    final window = entries.where((e) => !e.occurredAt.isBefore(windowStart)).toList();
    final thisMonth = buckets.last;
    final lastMonth = buckets.length > 1 ? buckets[buckets.length - 2] : null;
    final avgOut = buckets.fold<double>(0, (s, b) => s + b.cashOut) / buckets.length;
    final avgIn = buckets.fold<double>(0, (s, b) => s + b.cashIn) / buckets.length;
    final dailySpend = thisMonth.cashOut / now.day;
    final saved = thisMonth.cashIn == 0 ? null : (thisMonth.net / thisMonth.cashIn * 100);
    final change = lastMonth == null || lastMonth.cashOut == 0
        ? null
        : (thisMonth.cashOut - lastMonth.cashOut) / lastMonth.cashOut * 100;
    final top = Analytics.topSpending(window);
    final weekdays = Analytics.byWeekday(window);
    final wdMax = weekdays.fold<double>(0, math.max);
    final biggest = (window.where((e) => !e.isIn && e.transferId == null).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount)))
        .take(5)
        .toList();
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final kpis = [
      _Kpi(
        label: 'Spent this month',
        value: Fmt.money(thisMonth.cashOut),
        note: change == null
            ? 'No spending last month to compare'
            : '${change >= 0 ? 'Up' : 'Down'} ${change.abs().toStringAsFixed(0)}% on last month',
        icon: change != null && change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      ),
      _Kpi(
        label: 'Daily average spend',
        value: Fmt.money(dailySpend.roundToDouble()),
        note: 'Over the ${now.day} days of ${Fmt.month(now)}',
        icon: Icons.today_outlined,
      ),
      _Kpi(
        label: 'Kept this month',
        value: saved == null ? 'n/a' : '${saved.toStringAsFixed(0)}%',
        note: saved == null ? 'No cash in this month yet' : 'Of cash in, after cash out',
        icon: Icons.savings_outlined,
      ),
      _Kpi(
        label: 'Monthly average',
        value: Fmt.money(avgOut.roundToDouble()),
        note: 'Out, against ${Fmt.money(avgIn.roundToDouble())} in',
        icon: Icons.equalizer_rounded,
      ),
    ];

    final wide = context.isDesktop;
    final inOut = SectionCard(
      title: 'Cash in and out by month',
      child: InOutBarChart(buckets: buckets),
    );
    final balance = SectionCard(
      title: 'Balance at month end',
      child: BalanceLineChart(buckets: buckets, height: 240),
    );
    final where = SectionCard(
      title: 'Where the money went',
      trailing: Text('by note', style: t.bodySmall),
      child: top.isEmpty
          ? Text('No cash out in this window.', style: t.bodySmall)
          : Column(
              children: [
                for (final s in top)
                  RankBar(
                    label: '${s.$1}  (${s.$3}x)',
                    value: s.$2,
                    max: top.first.$2,
                    trailing: Fmt.money(s.$2),
                    color: c.outChart,
                  ),
              ],
            ),
    );
    final days = SectionCard(
      title: 'Spending by weekday',
      child: Column(
        children: [
          for (var i = 0; i < 7; i++)
            RankBar(
              label: names[i],
              value: weekdays[i],
              max: wdMax,
              trailing: Fmt.money(weekdays[i]),
              color: weekdays[i] == wdMax && wdMax > 0 ? c.outChart : c.muted.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
    final big = SectionCard(
      title: 'Largest expenses',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: biggest.isEmpty
          ? Text('No cash out in this window.', style: t.bodySmall)
          : Column(
              children: [
                for (final e in biggest)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const EntryTypeIcon(isIn: false, size: 36),
                    title: Text(e.title, overflow: TextOverflow.ellipsis),
                    subtitle: Text(Fmt.day(e.occurredAt)),
                    trailing: AmountText(e.amount, isIn: false),
                  ),
              ],
            ),
    );

    Widget pair(Widget a, Widget b) => wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, const SizedBox(height: 12), b]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, box) {
            final cols = box.maxWidth > 900 ? 4 : 2;
            final w = (box.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final k in kpis) SizedBox(width: w, child: k)],
            );
          },
        ),
        const SizedBox(height: 12),
        pair(inOut, balance),
        const SizedBox(height: 12),
        pair(where, days),
        const SizedBox(height: 12),
        big,
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final IconData icon;

  const _Kpi({required this.label, required this.value, required this.note, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatTile(
            label: label,
            icon: icon,
            iconColor: Theme.of(context).colorScheme.primary,
            value: Text(value, style: t.headlineSmall),
          ),
          const SizedBox(height: 4),
          Text(note, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
