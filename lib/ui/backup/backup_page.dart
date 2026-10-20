import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/cloud_sync.dart';
import '../../state/ledger_controller.dart';
import '../navigation/profile_footer.dart';
import '../widgets/common.dart';
import '../widgets/google_button.dart';

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
          const _CloudCard(),
        ],
      ),
    );
  }
}

/// Whether the books are also kept online, and a way to turn it on.
class _CloudCard extends StatelessWidget {
  const _CloudCard();

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSync?>();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final on = cloud?.signedIn ?? false;

    final lines = on
        ? [
            (Icons.cloud_done_outlined, 'Your books are saved online, so they are not lost if this phone is lost, broken or replaced.'),
            (Icons.devices_outlined, 'Sign in with the same Google account on another phone or the web and the same books appear.'),
            (Icons.wifi_off_rounded, 'Keeps working offline. Changes are saved here first and go online when there is internet.'),
            (Icons.history_rounded, 'Every change is kept with the value it replaced.'),
          ]
        : [
            (Icons.cloud_upload_outlined, 'Sign in with Google to save your books online, so they are not lost if this phone is lost, broken or replaced.'),
            (Icons.devices_outlined, 'Then sign in on another phone or the web and the same books appear.'),
            (Icons.wifi_off_rounded, 'Keeps working offline. Changes are saved here first and go online when there is internet.'),
          ];

    return SectionCard(
      title: 'Cloud sync',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on ? scheme.primary.withValues(alpha: 0.12) : scheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          on ? 'On' : 'Off',
          style: t.labelSmall?.copyWith(color: on ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
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
          if (cloud != null && on) ...[
            const SizedBox(height: 4),
            Text('Signed in as ${cloud.email ?? cloud.name}. ${_status(cloud)}', style: t.bodySmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: cloud.status == SyncState.syncing ? null : cloud.sync,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
            ),
          ] else if (cloud != null) ...[
            const SizedBox(height: 6),
            GoogleButton(onPressed: () => signInWithGoogle(context, cloud)),
          ],
        ],
      ),
    );
  }

  static String _status(CloudSync c) => switch (c.status) {
    SyncState.syncing => 'Syncing now.',
    SyncState.offline => c.pending > 0
        ? 'Offline: ${c.pending} ${c.pending == 1 ? 'change waits' : 'changes wait'} on this device.'
        : 'Offline right now.',
    SyncState.failed => 'Sync paused; it tries again on the next change.',
    _ => c.pending > 0
        ? '${c.pending} ${c.pending == 1 ? 'change' : 'changes'} to upload.'
        : 'Everything is saved online.',
  };
}
