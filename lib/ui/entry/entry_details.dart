import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'attachments.dart';
import 'entry_form_page.dart';

/// Shows one entry with its full change history. A bottom sheet on phones,
/// a dialog on desktop.
Future<void> showEntryDetails(BuildContext context, Entry entry, {bool readOnly = false}) {
  final body = EntryDetails(entry: entry, readOnly: readOnly);
  if (context.isPhone) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => EntryDetails(entry: entry, readOnly: readOnly, scroll: scroll),
      ),
    );
  }
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 520, height: 620, child: body),
    ),
  );
}

class EntryDetails extends StatelessWidget {
  final Entry entry;
  final bool readOnly;
  final ScrollController? scroll;

  const EntryDetails({super.key, required this.entry, this.readOnly = false, this.scroll});

  Future<void> _edit(BuildContext context) async {
    // This sheet closes first, so open the form from the navigator, whose
    // context outlives it.
    final nav = Navigator.of(context);
    nav.pop();
    await openAdaptive(nav.context, EntryFormPage(entry: entry), height: 640);
  }

  Future<void> _delete(BuildContext context) async {
    final ledger = context.read<LedgerController>();
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      message: entry.transferId != null
          ? 'This is part of a transfer. Both sides will be deleted.'
          : 'It will be removed from the account. The change log keeps a record.',
    );
    if (!ok) return;
    await ledger.deleteEntry(entry);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final canEdit = !readOnly && ledger.canEdit && entry.accountId == ledger.current?.id;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                Row(
                  children: [
                    EntryTypeIcon(isIn: entry.isIn, transfer: entry.transferId != null, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.transferId != null ? 'Transfer' : entry.type.label,
                            style: t.labelMedium,
                          ),
                          AmountText(
                            entry.amount,
                            isIn: entry.isIn,
                            signed: true,
                            style: t.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Line(icon: Icons.notes_rounded, label: 'Notes', value: entry.note.isEmpty ? 'No notes' : entry.note),
                _Line(
                  icon: Icons.event_outlined,
                  label: 'Date',
                  value: '${Fmt.day(entry.occurredAt)}, ${Fmt.time(entry.occurredAt)}',
                ),
                if (ledger.runningBalance(entry.id) != null)
                  _Line(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Balance after this entry',
                    value: Fmt.money(ledger.runningBalance(entry.id)!),
                  ),
                _Line(
                  icon: Icons.person_outline_rounded,
                  label: 'Added',
                  value: Fmt.stamp(entry.createdAt),
                ),
                if (entry.attachment != null && Attachments.supported) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Attachments.image(entry.attachment!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      child: SizedBox(height: 180, child: Attachments.image(entry.attachment!)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('History', style: t.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Every change is kept, so people sharing this account can see what it was before.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<EntryChange>>(
                  future: ledger.repo.historyOf(entry.id),
                  builder: (context, snap) {
                    final list = snap.data;
                    if (list == null) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          ChangeTile(change: list[i], last: i == list.length - 1),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (canEdit)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _delete(context),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _edit(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Line({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.cash.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: t.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fieldName(String k) => switch (k) {
  'amount' => 'Amount',
  'note' => 'Notes',
  'type' => 'Type',
  'occurred_at' => 'Date',
  _ => k,
};

String _fieldValue(String k, Object? v) {
  if (v == null) return '';
  return switch (k) {
    'amount' => Fmt.money(v as num),
    'type' => v == 'in' ? 'Cash In' : 'Cash Out',
    'occurred_at' => Fmt.stamp(fromIso(v as String)),
    'note' => (v as String).isEmpty ? '(empty)' : v,
    _ => '$v',
  };
}

/// One step in an entry's history, as a timeline row: who, when, and each
/// field's old value struck through beside the new one.
class ChangeTile extends StatelessWidget {
  final EntryChange change;
  final bool last;
  final String? title;

  const ChangeTile({super.key, required this.change, this.last = false, this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, verb) = switch (change.action) {
      ChangeAction.created => (Icons.add_rounded, c.inText, 'Added'),
      ChangeAction.updated => (Icons.edit_rounded, scheme.primary, 'Edited'),
      ChangeAction.deleted => (Icons.delete_outline_rounded, c.outText, 'Deleted'),
    };
    final who = change.changedByName.isEmpty ? 'You' : change.changedByName;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (!last) Expanded(child: Container(width: 2, color: c.hairline)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: t.titleSmall),
                  Text(
                    '$verb by $who  ·  ${Fmt.stamp(change.changedAt)}',
                    style: t.bodySmall,
                  ),
                  if (change.action == ChangeAction.updated)
                    for (final k in change.changedFields)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text('${_fieldName(k)}:', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              _fieldValue(k, change.before?[k]),
                              style: t.bodyMedium?.copyWith(
                                color: c.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: c.muted),
                            Text(_fieldValue(k, change.after?[k]), style: t.bodyMedium),
                          ],
                        ),
                      )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        () {
                          final d = change.after ?? change.before ?? {};
                          final note = (d['note'] as String?) ?? '';
                          return '${_fieldValue('type', d['type'])} ${_fieldValue('amount', d['amount'])}'
                              '${note.isEmpty ? '' : ', $note'}';
                        }(),
                        style: t.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
