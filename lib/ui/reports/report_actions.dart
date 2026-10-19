import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services/pdf_report.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';

/// Print, preview and export, shared by the home screen and report pages.
class ReportActions {
  ReportActions._();

  static ReportProfile profileOf(BuildContext context) {
    final s = context.read<SettingsController>();
    return ReportProfile(name: s.name, address: s.address, phone: s.phone);
  }

  /// The open account, as filtered on screen.
  static Future<Uint8List> _accountPdf(BuildContext context) {
    final ledger = context.read<LedgerController>();
    return PdfReport.build(
      title: ledger.current?.name ?? 'Account',
      periodLabel: ledger.period.label,
      profile: profileOf(context),
      sections: [
        ReportSection(
          ledger.current?.name ?? '',
          ledger.visible,
          opening: ledger.search.isEmpty ? ledger.openingBalance : 0,
        ),
      ],
    );
  }

  static Future<void> accountReport(BuildContext context) async {
    final ledger = context.read<LedgerController>();
    final bytes = await _accountPdf(context);
    if (!context.mounted) return;
    await previewPdf(context, bytes, '${ledger.current?.name ?? 'Account'} report');
  }

  static Future<void> printAccount(BuildContext context) async {
    final ledger = context.read<LedgerController>();
    final bytes = await _accountPdf(context);
    await Printing.layoutPdf(
      name: ledger.current?.name ?? 'Cash Flow',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> previewPdf(BuildContext context, Uint8List bytes, String title) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: PdfPreview(
            build: (_) async => bytes,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: '${_slug(title)}.pdf',
          ),
        ),
      ),
    );
  }

  static Future<void> saveCsv(BuildContext context, String csv, String name) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: '${_slug(name)}.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (uri != null && context.mounted) toast(context, 'CSV saved');
    } catch (e) {
      if (context.mounted) toast(context, 'Could not save the file: $e');
    }
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}
