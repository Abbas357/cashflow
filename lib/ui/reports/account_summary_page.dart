import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'report_data.dart';

/// Every account side by side: in, out, balance and last activity.
class AccountSummaryPage extends StatelessWidget {
  const AccountSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.read<LedgerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Account summary')),
      body: AllDataBuilder(
        builder: (context, data) {
          final t = Theme.of(context).textTheme;
          final c = context.cash;
          final all = Totals.of(data.entries);
          final cols = context.isDesktop ? 2 : 1;

          return PageBody(
            maxWidth: 980,
            children: [
              Card(
                color: AppTheme.brandColor,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net balance across ${data.accounts.length} accounts',
                        style: t.labelMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.money(all.balance),
                          style: t.displaySmall?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 6,
                        children: [
                          Text(
                            'In ${Fmt.money(all.cashIn)}',
                            style: t.bodyMedium?.copyWith(color: Colors.white),
                          ),
                          Text(
                            'Out ${Fmt.money(all.cashOut)}',
                            style: t.bodyMedium?.copyWith(color: Colors.white),
                          ),
                          Text(
                            '${all.count} entries',
                            style: t.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final w = (box.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final a in data.accounts)
                        SizedBox(
                          width: w,
                          child: Builder(
                            builder: (context) {
                              final list = data.of(a.id);
                              final tot = Totals.of(list);
                              final last = list.isEmpty ? null : list.last.occurredAt;
                              final outShare = tot.cashIn + tot.cashOut == 0
                                  ? 0.0
                                  : tot.cashOut / (tot.cashIn + tot.cashOut);
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    ledger.selectAccount(a);
                                    context.go(Routes.home);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(a.name, style: t.titleMedium)),
                                            if (a.isShared)
                                              Icon(Icons.group_outlined, size: 18, color: c.muted),
                                          ],
                                        ),
                                        Text(
                                          last == null
                                              ? 'No entries yet'
                                              : '${tot.count} entries, last on ${Fmt.dayShort(last)}',
                                          style: t.bodySmall,
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: StatTile(
                                                label: 'Cash in',
                                                value: AmountText(tot.cashIn, isIn: true),
                                              ),
                                            ),
                                            Expanded(
                                              child: StatTile(
                                                label: 'Cash out',
                                                value: AmountText(tot.cashOut, isIn: false),
                                              ),
                                            ),
                                            Expanded(
                                              child: StatTile(
                                                label: 'Balance',
                                                value: BalanceText(tot.balance),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Tooltip(
                                          message:
                                              'Cash out is ${(outShare * 100).toStringAsFixed(0)}% of all money moved',
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: ((1 - outShare) * 1000).round().clamp(1, 1000),
                                                  child: Container(height: 8, color: c.inChart),
                                                ),
                                                const SizedBox(width: 2),
                                                Expanded(
                                                  flex: (outShare * 1000).round().clamp(1, 1000),
                                                  child: Container(height: 8, color: c.outChart),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
