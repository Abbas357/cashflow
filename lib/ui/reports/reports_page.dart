import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../services/pdf_report.dart';
import '../../state/period.dart';
import '../widgets/common.dart';
import 'report_actions.dart';
import 'report_data.dart';

enum _Range { thisMonth, lastMonth, thisYear, all, custom }

/// Builds a PDF or CSV across chosen accounts and dates.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  _Range _range = _Range.thisMonth;
  DateTimeRange? _custom;
  Set<String>? _selected;
  bool _busy = false;

  Period get _period {
    final now = DateTime.now();
    return switch (_range) {
      _Range.thisMonth => Period(kind: PeriodKind.monthly, anchor: now),
      _Range.lastMonth => Period(kind: PeriodKind.monthly, anchor: DateTime(now.year, now.month - 1)),
      _Range.thisYear => Period(kind: PeriodKind.yearly, anchor: now),
      _Range.all => Period(kind: PeriodKind.all, anchor: now),
      _Range.custom => Period(
        kind: PeriodKind.custom,
        anchor: now,
        range: _custom ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
      ),
    };
  }

  List<ReportSection> _sections(AllData data) {
    final p = _period;
    final b = p.bounds;
    return [
      for (final a in data.accounts)
        if (_selected!.contains(a.id))
          ReportSection(
            a.name,
            data.of(a.id).where((e) => p.contains(e.occurredAt)).toList(),
            opening: b == null
                ? 0
                : data.of(a.id).where((e) => e.occurredAt.isBefore(b.$1)).fold(0.0, (s, e) => s + e.signed),
          ),
    ];
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _custom,
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _range = _Range.custom;
      });
    }
  }

  Future<void> _run(AllData data, String what) async {
    final sections = _sections(data);
    if (sections.isEmpty) {
      toast(context, 'Choose at least one account');
      return;
    }
    setState(() => _busy = true);
    try {
      if (what == 'csv') {
        await ReportActions.saveCsv(context, PdfReport.csv(sections), 'cash_flow_${_period.label}');
        return;
      }
      final profile = await ReportActions.profileOf(context);
      final bytes = await PdfReport.build(
        title: sections.length == 1 ? sections.first.accountName : 'All accounts report',
        periodLabel: _period.label,
        profile: profile,
        sections: sections,
        includeSummary: true,
      );
      if (!mounted) return;
      if (what == 'print') {
        await Printing.layoutPdf(name: 'Cash Flow report', onLayout: (_) async => bytes);
      } else {
        await ReportActions.previewPdf(context, bytes, 'Report');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports: all accounts')),
      body: AllDataBuilder(
        builder: (context, data) {
          _selected ??= data.accounts.map((a) => a.id).toSet();
          final labels = {
            _Range.thisMonth: 'This month',
            _Range.lastMonth: 'Last month',
            _Range.thisYear: 'This year',
            _Range.all: 'All time',
            _Range.custom: 'Custom',
          };
          return PageBody(
            children: [
              SectionCard(
                title: 'Dates',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in _Range.values)
                          ChoiceChip(
                            label: Text(labels[r]!),
                            selected: _range == r,
                            onSelected: (_) => r == _Range.custom ? _pickCustom() : setState(() => _range = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_period.label, style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Accounts',
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _selected = _selected!.length == data.accounts.length
                        ? <String>{}
                        : data.accounts.map((a) => a.id).toSet();
                  }),
                  child: Text(_selected!.length == data.accounts.length ? 'Clear' : 'Select all'),
                ),
                child: Column(
                  children: [
                    for (final a in data.accounts)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected!.contains(a.id),
                        title: Text(a.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected!.add(a.id);
                          } else {
                            _selected!.remove(a.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The PDF opens with a summary table, then every account with its '
                'entries, running balance and totals. Your name and address from '
                'Settings appear in the header.',
                style: t.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(data, 'preview'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Preview PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(data, 'print'),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(data, 'csv'),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(color: AppTheme.brandColor),
              ],
            ],
          );
        },
      ),
    );
  }
}
