import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'common.dart';

/// One entry row: marker, note, time, amount and running balance.
class EntryTile extends StatelessWidget {
  final Entry entry;
  final double? balance;
  final String? accountName;
  final bool showDate;
  final VoidCallback? onTap;

  const EntryTile({
    super.key,
    required this.entry,
    this.balance,
    this.accountName,
    this.showDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final meta = <String>[
      showDate ? Fmt.stamp(entry.occurredAt) : Fmt.time(entry.occurredAt),
      ?accountName,
    ].join('  ·  ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            EntryTypeIcon(isIn: entry.isIn, transfer: entry.transferId != null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          style: t.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.attachment != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.attach_file_rounded, size: 14, color: c.muted),
                      ],
                      if (entry.wasEdited) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.hairline),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Edited', style: t.labelSmall?.copyWith(fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  entry.amount,
                  isIn: entry.isIn,
                  signed: true,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Bal ${Fmt.money(balance!)}',
                    style: t.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
