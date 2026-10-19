import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/calculator.dart';
import '../../core/utils/formatters.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';

/// Moves money between two accounts. Writes a Cash Out in one and a
/// matching Cash In in the other, linked so they edit and delete together.
class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  String? _from;
  String? _to;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    final ledger = context.read<LedgerController>();
    final editable = ledger.accounts.where((a) => a.canEdit).toList();
    _from = ledger.current?.canEdit == true ? ledger.current!.id : editable.firstOrNull?.id;
    _to = editable.where((a) => a.id != _from).firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ledger = context.read<LedgerController>();
    final v = evaluateExpression(_amount.text);
    if (_from == null || _to == null || _from == _to) {
      setState(() => _error = 'Pick two different accounts');
      return;
    }
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    final from = ledger.accounts.firstWhere((a) => a.id == _from);
    final to = ledger.accounts.firstWhere((a) => a.id == _to);
    await ledger.transfer(
      from: from,
      to: to,
      amount: double.parse(v.toStringAsFixed(2)),
      at: _date,
      note: _note.text,
    );
    if (!mounted) return;
    toast(context, 'Moved ${Fmt.money(v)} from ${from.name} to ${to.name}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final t = Theme.of(context).textTheme;
    final accounts = ledger.accounts.where((a) => a.canEdit).toList();

    DropdownButtonFormField<String> picker(String label, String? value, ValueChanged<String?> on) =>
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: on,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: accounts.length < 2
          ? EmptyState(
              icon: Icons.swap_horiz_rounded,
              title: 'You need two accounts',
              message: 'Create another account to move money between them.',
              action: FilledButton(
                onPressed: () async {
                  final name = await promptText(context, title: 'New account', action: 'Create');
                  if (name != null) await ledger.createAccount(name);
                  if (mounted) setState(() {});
                },
                child: const Text('Add account'),
              ),
            )
          : PageBody(
              maxWidth: 560,
              children: [
                Text(
                  'Records a Cash Out in the first account and a Cash In in the '
                  'second. Editing or deleting one side updates the other.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 16),
                picker('From', _from, (v) => setState(() => _from = v)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Swap',
                      onPressed: () => setState(() {
                        final f = _from;
                        _from = _to;
                        _to = f;
                      }),
                      icon: const Icon(Icons.swap_vert_rounded),
                    ),
                  ),
                ),
                picker('To', _to, (v) => setState(() => _to = v)),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: t.headlineSmall,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: Fmt.currency.isEmpty ? null : '${Fmt.currency}  ',
                    errorText: _error,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(Fmt.day(_date)),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.brandColor, foregroundColor: Colors.white),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
              ],
            ),
    );
  }
}
