import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../state/ledger_controller.dart';

/// The bottom of the ledger: two big bright buttons, then the totals for
/// what is on screen.
class CashBar extends StatelessWidget {
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;

  const CashBar({super.key, required this.onCashIn, required this.onCashOut});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final tot = ledger.visibleTotals;
    final scheme = Theme.of(context).colorScheme;
    final c = context.cash;

    return Material(
      color: scheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: MaxWidth(
            maxWidth: 940,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.isPhone ? 12 : 20,
                12,
                context.isPhone ? 12 : 20,
                10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ledger.canEdit)
                    Row(
                      children: [
                        Expanded(
                          child: _BigButton(
                            label: 'Cash In',
                            icon: Icons.add_rounded,
                            color: c.inButton,
                            onTap: onCashIn,
                            shortcut: 'Ctrl+I',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigButton(
                            label: 'Cash Out',
                            icon: Icons.remove_rounded,
                            color: c.outButton,
                            onTap: onCashOut,
                            shortcut: 'Ctrl+O',
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: c.muted),
                          const SizedBox(width: 8),
                          Text(
                            'View only: shared with you',
                            style: TextStyle(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _Total('Total Cash In', Fmt.money(tot.cashIn), c.inText),
                        VerticalDivider(width: 1, color: c.hairline),
                        _Total('Total Cash Out', Fmt.money(tot.cashOut), c.outText),
                        VerticalDivider(width: 1, color: c.hairline),
                        _Total(
                          'Balance',
                          Fmt.money(tot.balance),
                          tot.balance < 0 ? c.outText : scheme.onSurface,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String shortcut;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label ($shortcut)',
      waitDuration: const Duration(milliseconds: 600),
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 24),
        label: Text(label),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Total(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          children: [
            Text(
              label,
              style: t.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: t.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
