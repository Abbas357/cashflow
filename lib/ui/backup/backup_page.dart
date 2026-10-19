import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';

/// Local backups to a file, and the cloud sync that is coming.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  static const _format = 'cash_flow_backup';

  Future<void> _export() async {
    final ledger = context.read<LedgerController>();
    setState(() => _busy = true);
    try {
      final dump = await ledger.repo.dump();
      final json = const JsonEncoder.withIndent(' ').convert({
        'format': _format,
        'version': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'data': dump,
      });
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final uri = await FilePicker.saveFile(
        fileName: 'cash_flow_backup_$stamp.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (uri != null && mounted) toast(context, 'Backup saved');
    } catch (e) {
      if (mounted) toast(context, 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final ledger = context.read<LedgerController>();
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null || !mounted) return;
    final ok = await confirm(
      context,
      title: 'Restore this backup?',
      message: 'Everything currently in the app is replaced by the backup. '
          'Export a backup first if you want to keep it.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final text = await file.xFile.readAsString();
      final root = jsonDecode(text) as Map<String, dynamic>;
      if (root['format'] != _format) throw const FormatException('Not a Cash Flow backup');
      final data = (root['data'] as Map<String, dynamic>).map(
        (table, rows) => MapEntry(
          table,
          (rows as List).map((r) => (r as Map).cast<String, Object?>()).toList(),
        ),
      );
      await ledger.repo.restore(data);
      await ledger.reload();
      if (mounted) toast(context, 'Backup restored');
    } catch (e) {
      if (mounted) toast(context, 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: PageBody(
        maxWidth: 640,
        children: [
          SectionCard(
            title: 'On this device',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Save every account, entry and change history to a single file. '
                  'Keep it on a USB drive, email it to yourself, or move it to a new phone.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export backup'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Restore from file'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(color: AppTheme.brandColor),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Cloud sync',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Coming soon', style: t.labelSmall?.copyWith(color: scheme.primary)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  (Icons.wifi_off_rounded, 'Keeps working offline. Entries are saved on the device first.'),
                  (Icons.sync_rounded, 'Syncs in the background with Supabase whenever there is internet.'),
                  (Icons.contacts_outlined, 'Share accounts with people from your contacts, as Can edit or View only.'),
                  (Icons.history_rounded, 'Everyone sees each change and the value it replaced.'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(line.$1, size: 20, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(line.$2, style: t.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
