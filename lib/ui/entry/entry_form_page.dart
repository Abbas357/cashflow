import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/calculator.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import 'attachments.dart';
import 'calculator_sheet.dart';

/// Adds a new entry, or edits [entry] when given.
class EntryFormPage extends StatefulWidget {
  final EntryType type;
  final Entry? entry;

  /// Opened from its own address (/cash-in, /cash-out). The form then keeps
  /// its address in step with Cash In / Cash Out, and keeps a draft so a
  /// browser refresh brings back what was typed.
  final bool routed;

  const EntryFormPage({
    super.key,
    this.type = EntryType.cashIn,
    this.entry,
    this.routed = false,
  });

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  late EntryType _type = widget.entry?.type ?? widget.type;
  late final _amount = TextEditingController(
    text: widget.entry == null ? '' : _plain(widget.entry!.amount),
  );
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late DateTime _date = widget.entry?.occurredAt ?? DateTime.now();
  late String? _attachment = widget.entry?.attachment;
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  List<String> _suggestions = [];
  String? _error;
  bool _saving = false;
  int _savedCount = 0;

  late final SettingsController _settings = context.read<SettingsController>();

  bool get _editing => widget.entry != null;

  /// Drafts older than this are stale and not restored.
  static const _draftLife = Duration(hours: 2);

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    if (widget.routed) {
      _restoreDraft();
      _amount.addListener(_saveDraft);
      _note.addListener(_saveDraft);
    }
  }

  void _restoreDraft() {
    final raw = _settings.entryDraft;
    if (raw == null) return;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final saved = DateTime.parse(d['saved'] as String);
      final account = context.read<LedgerController>().current?.id;
      if (d['account'] != account || DateTime.now().difference(saved) > _draftLife) {
        _settings.setEntryDraft(null);
        return;
      }
      _type = EntryType.parse(d['type'] as String);
      _amount.text = d['amount'] as String? ?? '';
      _note.text = d['note'] as String? ?? '';
      _date = DateTime.tryParse(d['at'] as String? ?? '') ?? _date;
    } catch (_) {
      _settings.setEntryDraft(null);
    }
  }

  void _saveDraft() {
    if (!widget.routed) return;
    if (_amount.text.isEmpty && _note.text.isEmpty) {
      _settings.setEntryDraft(null);
      return;
    }
    _settings.setEntryDraft(jsonEncode({
      'account': context.read<LedgerController>().current?.id,
      'type': _type.code,
      'amount': _amount.text,
      'note': _note.text,
      'at': _date.toIso8601String(),
      'saved': DateTime.now().toIso8601String(),
    }));
  }

  void _setType(EntryType type) {
    if (type == _type) return;
    setState(() => _type = type);
    _saveDraft();
    if (widget.routed) {
      // Same popup, new address; neglect() replaces it rather than adding
      // a history step.
      final ledger = context.read<LedgerController>();
      Router.neglect(
        context,
        () => context.go(Routes.withQuery(Routes.newEntry(type, ledger.current!.id), ledger.viewQuery)),
      );
    }
  }

  Future<void> _loadSuggestions() async {
    final ledger = context.read<LedgerController>();
    final acc = ledger.current;
    if (acc == null) return;
    final s = await ledger.repo.noteSuggestions(acc.id);
    if (mounted) setState(() => _suggestions = s);
  }

  @override
  void dispose() {
    // Closed on purpose (saved, Back, or the browser's Back button). A
    // refresh never gets here, so its draft survives.
    if (widget.routed) _settings.setEntryDraft(null);
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  double? get _parsed => evaluateExpression(_amount.text);

  Future<void> _calculator() async {
    final v = await showCalculator(context, initial: _amount.text);
    if (v != null) {
      _amount.text = _plain(double.parse(v.toStringAsFixed(2)));
      setState(() => _error = null);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
      _saveDraft();
    }
  }

  Future<void> _pickTime() async {
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (tm != null) {
      setState(() => _date = DateTime(_date.year, _date.month, _date.day, tm.hour, tm.minute));
      _saveDraft();
    }
  }

  void _shiftDay(int by) {
    setState(
      () => _date = DateTime(_date.year, _date.month, _date.day + by, _date.hour, _date.minute),
    );
    _saveDraft();
  }

  Future<void> _attach() async {
    ImageSource? source = ImageSource.gallery;
    if (Attachments.hasCamera) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    try {
      final path = await Attachments.pick(source);
      if (path != null) setState(() => _attachment = path);
    } catch (_) {
      if (mounted) toast(context, 'Could not attach the photo.');
    }
  }

  /// Saves, then either closes or clears the form for the next entry.
  Future<void> _save({required bool exit}) async {
    final v = _parsed;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      _amountFocus.requestFocus();
      return;
    }
    final amount = double.parse(v.toStringAsFixed(2));
    final ledger = context.read<LedgerController>();
    setState(() => _saving = true);
    try {
      if (_editing) {
        await ledger.updateEntry(
          widget.entry!.copyWith(
            type: _type,
            amount: amount,
            note: _note.text.trim(),
            occurredAt: _date,
            attachment: _attachment,
            clearAttachment: _attachment == null,
          ),
        );
      } else {
        await ledger.addEntry(
          type: _type,
          amount: amount,
          note: _note.text.trim(),
          at: _date,
          attachment: _attachment,
        );
      }
      if (!mounted) return;
      if (exit) {
        Navigator.of(context).pop(true);
        return;
      }
      _savedCount++;
      toast(context, '${_type.label} of ${Fmt.money(amount)} saved');
      _amount.clear();
      _note.clear();
      setState(() {
        _attachment = null;
        _error = null;
        _date = DateTime.now();
      });
      _amountFocus.requestFocus();
      _loadSuggestions();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      message: e.transferId != null
          ? 'This is part of a transfer. Both sides will be deleted.'
          : 'It will be removed from the account. The change log keeps a record.',
    );
    if (!ok || !mounted) return;
    await context.read<LedgerController>().deleteEntry(e);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final color = _type.isIn ? c.inText : c.outText;
    final button = _type.isIn ? c.inButton : c.outButton;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _save(exit: true),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _save(exit: _editing),
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_savedCount > 0),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit entry' : _type.label),
              Text(ledger.current?.name ?? '', style: t.labelSmall),
            ],
          ),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.errorColor,
                onPressed: _delete,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                for (final type in EntryType.values) ...[
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => _setType(type),
                    selectedColor: type.isIn ? c.inButton : c.outButton,
                    side: BorderSide(
                      color: _type == type ? Colors.transparent : Theme.of(context).colorScheme.outline,
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _type == type ? Colors.white : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              focusNode: _amountFocus,
              autofocus: !_editing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-*/×÷−]')),
              ],
              style: t.headlineMedium?.copyWith(color: color),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(exit: _editing),
              decoration: InputDecoration(
                labelText: _type.label,
                labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
                floatingLabelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
                prefixText: Fmt.currency.isEmpty ? null : '${Fmt.currency}  ',
                errorText: _error,
                helperText: _amount.text.contains(RegExp(r'[+\-*/×÷−]')) && _parsed != null
                    ? '= ${Fmt.number(_parsed!)}'
                    : null,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Calculator',
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: _calculator,
                ),
              ),
            ),
            const SizedBox(height: 16),
            RawAutocomplete<String>(
              textEditingController: _note,
              focusNode: _noteFocus,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return _suggestions
                    .where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q)
                    .take(6);
              },
              fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
                controller: ctrl,
                focusNode: focus,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'What was it for?',
                  suffixIcon: Attachments.supported
                      ? IconButton(
                          tooltip: 'Attach a photo',
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: _attach,
                        )
                      : null,
                ),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260, maxWidth: 480),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.history_rounded, size: 18),
                            title: Text(o),
                            onTap: () => onSelected(o),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_attachment != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Attachments.image(_attachment!),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove photo',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _attachment = null),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _FieldBox(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous day',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _shiftDay(-1),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(Fmt.formDate(_date), style: t.bodyLarge),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next day',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => _shiftDay(1),
                        ),
                        IconButton(
                          tooltip: 'Pick a date',
                          icon: Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.primary),
                          onPressed: _pickDate,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _FieldBox(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(Fmt.time(_date), style: t.bodyLarge),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(Icons.schedule_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 16),
              Text(
                'Changes are recorded in the entry history, so anyone sharing '
                'this account can see the previous values.',
                style: t.bodySmall,
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _editing
                ? FilledButton(
                    onPressed: _saving ? null : () => _save(exit: true),
                    style: FilledButton.styleFrom(backgroundColor: button, foregroundColor: Colors.white),
                    child: const Text('Save changes'),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _save(exit: true),
                          // A soft tint of the entry's colour, so it reads as
                          // a button beside the solid one.
                          style: OutlinedButton.styleFrom(
                            backgroundColor: button.withValues(alpha: 0.08),
                            foregroundColor: button,
                            side: BorderSide(color: button.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Save & exit', maxLines: 1, softWrap: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : () => _save(exit: false),
                          style: FilledButton.styleFrom(
                            backgroundColor: button,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Save & continue', maxLines: 1, softWrap: false),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A box drawn like a text field, for the date and time pickers.
class _FieldBox extends StatelessWidget {
  final Widget child;

  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }
}
