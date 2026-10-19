import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/analytics.dart';
import '../../../state/ledger_controller.dart';
import '../../accounts/sharing_page.dart';
import '../../reports/charts.dart';
import '../../reports/insights_page.dart';
import '../../widgets/common.dart';

/// The right-hand panel on wide screens: where the open account stands.
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final acc = ledger.current;
    if (acc == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final all = ledger.accountTotals;
    final now = DateTime.now();
    final month = Totals.of(
      ledger.allEntries.where(
        (e) => e.occurredAt.year == now.year && e.occurredAt.month == now.month,
      ),
    );
    final months = Analytics.lastMonths(ledger.allEntries, 6, (d) => Fmt.monthShort(d).split(' ').first);
    final top = Analytics.topSpending(
      ledger.allEntries
          .where((e) => e.occurredAt.year == now.year && e.occurredAt.month == now.month)
          .toList(),
      limit: 4,
    );

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Overview', style: t.titleLarge),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.brandColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance in ${acc.name}',
                    style: t.labelMedium?.copyWith(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.money(all.balance),
                      style: t.displaySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${all.count} entries in total',
                    style: t.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SectionCard(
                  child: StatTile(
                    label: 'In this month',
                    icon: Icons.south_west_rounded,
                    iconColor: c.inText,
                    value: AmountText(month.cashIn, isIn: true, style: t.titleLarge),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionCard(
                  child: StatTile(
                    label: 'Out this month',
                    icon: Icons.north_east_rounded,
                    iconColor: c.outText,
                    value: AmountText(month.cashOut, isIn: false, style: t.titleLarge),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Last 6 months',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsPage()),
              ),
              child: const Text('Insights'),
            ),
            child: InOutBarChart(buckets: months, height: 170),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Top spending this month',
              child: Column(
                children: [
                  for (final s in top)
                    RankBar(
                      label: s.$1,
                      value: s.$2,
                      max: top.first.$2,
                      trailing: Fmt.money(s.$2),
                      color: c.outChart,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Sharing'),
              subtitle: Text(acc.isShared ? 'Shared with others' : 'Only you'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openAdaptive(context, SharingPage(account: acc)),
            ),
          ),
        ],
      ),
    );
  }
}
