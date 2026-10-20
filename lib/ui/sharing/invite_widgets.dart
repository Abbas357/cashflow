import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/cloud_config.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../services/cloud_sync.dart';
import '../../services/notifier.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';

/// The invitation link a QR code holds.
String inviteLink(String code) => '${CloudConfig.webAppUrl}join/$code';

final _codeInLink = RegExp(r'/join/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})');
final _bareCode = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// The code in a scanned link (or a bare code), or null if it is not one.
String? inviteCodeFrom(String? text) {
  final t = text?.trim() ?? '';
  if (_bareCode.hasMatch(t)) return t.toLowerCase();
  return _codeInLink.firstMatch(t)?.group(1)?.toLowerCase();
}

/// Scanning works in the Android app; on the web, a phone's camera opens
/// the link instead.
bool get canScanInvites => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Opens the camera, and the invitation in a scanned code.
Future<void> scanInvite(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _ScanPage()),
  );
  if (code != null && context.mounted) context.go(Routes.join(code));
}

/// Shows the account and opens its ledger.
Future<void> openAccount(BuildContext context, String id) async {
  final ledger = context.read<LedgerController>();
  final account = ledger.accounts.where((a) => a.id == id).firstOrNull;
  if (account != null) await ledger.selectAccount(account);
  if (context.mounted) context.go(Routes.account(id));
}

Future<void> acceptInvitation(BuildContext context, Invitation i) async {
  final cloud = context.read<CloudSync>();
  try {
    final id = await cloud.acceptInvitation(i);
    // So they hear about the other side's entries from now on.
    await Notifier.requestPermission();
    if (!context.mounted) return;
    toast(context, 'You joined "${i.accountName}"');
    await openAccount(context, id);
  } catch (_) {
    if (context.mounted) toast(context, 'Could not accept. Check the connection and try again.');
  }
}

Future<void> declineInvitation(BuildContext context, Invitation i) async {
  final ok = await confirm(
    context,
    title: 'Decline "${i.accountName}"?',
    message: '${i.invitedBy.isEmpty ? 'The owner' : i.invitedBy} will see that you declined. '
        'They can invite you again later.',
    confirmLabel: 'Decline',
  );
  if (!ok || !context.mounted) return;
  try {
    await context.read<CloudSync>().declineInvitation(i);
  } catch (_) {
    if (context.mounted) toast(context, 'Could not decline. Check the connection and try again.');
  }
}

/// "Abbas shared Flat Expenditures with you", with Accept and Decline.
class InvitationCard extends StatelessWidget {
  final Invitation invitation;

  const InvitationCard({super.key, required this.invitation});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final i = invitation;
    final who = i.invitedBy.isEmpty ? 'Someone' : i.invitedBy;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mail_outline_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: who, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' shared '),
                      TextSpan(text: i.accountName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: ' with you. ${i.role.label}.'),
                    ],
                  ),
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => declineInvitation(context, i), child: const Text('Decline')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => acceptInvitation(context, i), child: const Text('Accept')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows a QR code that lets whoever scans it join [account] as [role].
Future<void> showInviteQr(BuildContext context, Account account, AccountRole role) => showDialog<void>(
  context: context,
  builder: (_) => _QrDialog(account: account, role: role),
);

class _QrDialog extends StatefulWidget {
  final Account account;
  final AccountRole role;

  const _QrDialog({required this.account, required this.role});

  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  InviteCode? _code;
  bool _failed = false;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _make();
  }

  Future<void> _make() async {
    setState(() => _failed = false);
    try {
      final code = await context.read<CloudSync>().createInviteCode(widget.account.id, widget.role);
      if (mounted) setState(() => _code = code);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _stop() async {
    final code = _code;
    if (code == null) return;
    try {
      await context.read<CloudSync>().stopInviteCode(code.code);
      if (mounted) setState(() => _stopped = true);
    } catch (_) {
      if (mounted) toast(context, 'Could not stop it. Check the connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final code = _code;
    final Widget body;
    if (_failed) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: context.cash.muted),
          const SizedBox(height: 12),
          Text('A QR code needs the internet. Check the connection and try again.',
              style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _make, child: const Text('Try again')),
        ],
      );
    } else if (code == null) {
      body = const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    } else if (_stopped) {
      body = Text('Stopped. Nobody else can join with this code.', style: t.bodyMedium, textAlign: TextAlign.center);
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dark on white in both themes, so every camera reads it.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: inviteLink(code.code), size: 220, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 14),
          Text('"${widget.account.name}", ${widget.role.label.toLowerCase()}', style: t.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'In the Cash Flow app: Sharing, then Scan QR code. Or point any phone camera at it to open it in the browser.',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text('Works until ${Fmt.stamp(code.expiresAt)}, or until you stop it.',
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Scan to join'),
      content: SizedBox(width: 300, child: body),
      actions: [
        if (code != null && !_stopped)
          TextButton(onPressed: _stop, child: const Text('Stop this code')),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  bool _wrong = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _found(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = inviteCodeFrom(b.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (!_wrong) setState(() => _wrong = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan invitation')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scanner, onDetect: _found),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Text(
                _wrong
                    ? 'That code is not a Cash Flow invitation. Point at the QR code on the other phone.'
                    : 'Point the camera at the QR code on the other phone.',
                style: t.bodyMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// At the top of the ledger while someone's invitation waits: the newest
/// one with Accept and Decline, and a link to the rest.
class InvitationBanner extends StatelessWidget {
  const InvitationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<CloudSync?>()?.invitations ?? const <Invitation>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final more = list.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: MaxWidth(
        maxWidth: 940,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvitationCard(invitation: list.first),
            if (more > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(Routes.sharing),
                  child: Text('$more more ${more == 1 ? 'invitation' : 'invitations'}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
