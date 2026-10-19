import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/ledger_controller.dart';
import '../../../state/period.dart';

/// All / Daily / Weekly / Monthly / Yearly chips, and a row to step
/// through the chosen period.
class PeriodBar extends StatelessWidget {
  final VoidCallback onPickRange;

  const PeriodBar({super.key, required this.onPickRange});

  Future<void> _jump(BuildContext context, LedgerController ledger) async {
    final p = ledger.period;
    if (p.kind == PeriodKind.custom) return onPickRange();
    if (!p.canStep) return;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: p.anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) ledger.jumpTo(d);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final p = ledger.period;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final kinds = [
      PeriodKind.all,
      PeriodKind.daily,
      PeriodKind.weekly,
      PeriodKind.monthly,
      PeriodKind.yearly,
      if (p.kind == PeriodKind.custom) PeriodKind.custom,
    ];

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final k in kinds)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(k.label),
                    selected: p.kind == k,
                    onSelected: (_) => ledger.setPeriodKind(k),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.kind == k ? scheme.primary : null,
                    ),
                    side: BorderSide(
                      color: p.kind == k
                          ? scheme.primary.withValues(alpha: 0.4)
                          : scheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: p.canStep ? () => ledger.stepPeriod(-1) : null,
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _jump(context, ledger),
                    child: Center(
                      child: Text(
                        p.label,
                        style: t.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (p.kind == PeriodKind.custom)
                  IconButton(
                    tooltip: 'Clear range',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => ledger.setPeriodKind(PeriodKind.all),
                  )
                else
                  IconButton(
                    tooltip: 'Next',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: p.canStep ? () => ledger.stepPeriod(1) : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
