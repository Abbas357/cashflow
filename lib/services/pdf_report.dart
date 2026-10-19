import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/formatters.dart';
import '../data/models/models.dart';
import '../state/ledger_controller.dart';

/// Who the report is for, printed in its header.
class ReportProfile {
  final String name;
  final String address;
  final String phone;
  const ReportProfile({this.name = '', this.address = '', this.phone = ''});
}

/// One account's part of a report.
class ReportSection {
  final String accountName;
  final List<Entry> entries;
  final double opening;
  const ReportSection(this.accountName, this.entries, {this.opening = 0});
}

/// Builds printable PDFs. Plain, black on white, so they print well and
/// read the same on paper as on screen.
class PdfReport {
  PdfReport._();

  static const _green = PdfColor.fromInt(0xFF15803D);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _brand = PdfColor.fromInt(0xFF006B3C);
  static const _line = PdfColor.fromInt(0xFFDDDDDD);
  static const _muted = PdfColor.fromInt(0xFF666666);

  static Future<Uint8List> build({
    required String title,
    required String periodLabel,
    required ReportProfile profile,
    required List<ReportSection> sections,
    bool includeSummary = false,
  }) async {
    final doc = pw.Document(title: title, author: profile.name);
    final base = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    doc.addPage(
      pw.MultiPage(
        theme: base,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        header: (ctx) => ctx.pageNumber == 1 ? _header(title, periodLabel, profile) : pw.SizedBox(),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Cash Flow  |  Generated ${Fmt.stamp(DateTime.now())}  |  Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (ctx) => [
          if (includeSummary && sections.length > 1) ...[
            _summaryTable(sections),
            pw.SizedBox(height: 18),
          ],
          for (final s in sections) ..._section(s, showName: sections.length > 1),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _header(String title, String period, ReportProfile p) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (p.name.isNotEmpty)
                    pw.Text(p.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  if (p.address.isNotEmpty)
                    pw.Text(p.address, style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  if (p.phone.isNotEmpty)
                    pw.Text(p.phone, style: const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _brand)),
                pw.Text(period, style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _brand, thickness: 1.2),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _summaryTable(List<ReportSection> sections) {
    var ti = 0.0, to = 0.0;
    final rows = <List<String>>[];
    for (final s in sections) {
      final t = Totals.of(s.entries);
      ti += t.cashIn;
      to += t.cashOut;
      rows.add([s.accountName, Fmt.money(t.cashIn), Fmt.money(t.cashOut), Fmt.money(t.balance)]);
    }
    rows.add(['Total', Fmt.money(ti), Fmt.money(to), Fmt.money(ti - to)]);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Account', 'Cash In', 'Cash Out', 'Balance'],
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F4F2)),
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
      ],
    );
  }

  static List<pw.Widget> _section(ReportSection s, {required bool showName}) {
    final sorted = [...s.entries]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final tot = Totals.of(sorted);
    var running = s.opening;
    final rows = <List<String>>[];
    for (final e in sorted) {
      running += e.signed;
      rows.add([
        '${Fmt.dayShort(e.occurredAt)}\n${Fmt.time(e.occurredAt)}',
        e.title,
        e.isIn ? Fmt.number(e.amount) : '',
        e.isIn ? '' : Fmt.number(e.amount),
        Fmt.number(running),
      ]);
    }

    return [
      if (showName)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
          child: pw.Text(s.accountName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
      pw.Row(
        children: [
          _stat('Total Cash In', Fmt.money(tot.cashIn), _green),
          pw.SizedBox(width: 8),
          _stat('Total Cash Out', Fmt.money(tot.cashOut), _red),
          pw.SizedBox(width: 8),
          _stat('Balance', Fmt.money(tot.balance), tot.balance < 0 ? _red : PdfColors.black),
        ],
      ),
      pw.SizedBox(height: 10),
      if (s.opening != 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Opening balance: ${Fmt.money(s.opening)}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ),
      if (rows.isEmpty)
        pw.Text('No entries in this period.', style: const pw.TextStyle(fontSize: 10, color: _muted))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Notes', 'Cash In', 'Cash Out', 'Balance'],
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F4F2)),
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
          columnWidths: {
            0: const pw.FixedColumnWidth(72),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(66),
            3: const pw.FixedColumnWidth(66),
            4: const pw.FixedColumnWidth(72),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          cellDecoration: (col, data, row) => const pw.BoxDecoration(),
          textStyleBuilder: (col, data, row) {
            if (row == 0) return null;
            if (col == 2) return const pw.TextStyle(fontSize: 9, color: _green);
            if (col == 3) return const pw.TextStyle(fontSize: 9, color: _red);
            return null;
          },
        ),
      pw.SizedBox(height: 18),
    ];
  }

  static pw.Widget _stat(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// The same data as a CSV file for spreadsheets.
  static String csv(List<ReportSection> sections) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Account,Date,Time,Type,Amount,Notes\n');
    for (final s in sections) {
      final sorted = [...s.entries]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      for (final e in sorted) {
        b.writeln([
          q(s.accountName),
          Fmt.dayShort(e.occurredAt),
          Fmt.time(e.occurredAt),
          e.isIn ? 'Cash In' : 'Cash Out',
          e.amount.toStringAsFixed(2),
          q(e.note),
        ].join(','));
      }
    }
    return b.toString();
  }
}
