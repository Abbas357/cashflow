import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../services/cloud_sync.dart';
import '../../services/notifier.dart';
import '../../state/settings_controller.dart';
import '../navigation/profile_footer.dart';
import '../widgets/common.dart';
import '../widgets/google_button.dart';
import 'invite_widgets.dart';

/// Where an invitation QR code or link lands (`/join/<code>`): says which
/// account it is for and who shared it, and joins on Accept.
///
/// Signed out, it asks to sign in with Google first and keeps the code, so
/// the invitation is offered again as soon as they are back.
class JoinPage extends StatefulWidget {
  final String code;

  const JoinPage({super.key, required this.code});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  Future<CodeDetails?>? _details;
  bool _joining = false;

  String? get _code => inviteCodeFrom(widget.code);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cloud = context.watch<CloudSync?>();
    if (_details == null && cloud != null && cloud.signedIn && _code != null) {
      _details = cloud.codeDetails(_code!);
    }
  }

  Future<void> _signIn(CloudSync cloud) async {
    await context.read<SettingsController>().setPendingJoin(_code);
    if (mounted) await signInWithGoogle(context, cloud);
  }

  Future<void> _join(CloudSync cloud, CodeDetails d) async {
    setState(() => _joining = true);
    try {
      final id = await cloud.joinWithCode(_code!);
      await Notifier.requestPermission();
      if (!mounted) return;
      toast(context, 'You joined "${d.accountName}"');
      await openAccount(context, id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _joining = false);
      toast(context, 'Could not join. The code may have expired, or the connection dropped.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSync?>();

    Widget message(IconData icon, String title, String text, [Widget? action]) =>
        EmptyState(icon: icon, title: title, message: text, action: action);

    final Widget body;
    if (_code == null) {
      body = message(Icons.qr_code_2_rounded, 'Not an invitation', 'This link does not hold a Cash Flow invitation.');
    } else if (cloud == null || !cloud.available) {
      body = message(Icons.cloud_off_outlined, 'Sign-in is not set up', 'This build of Cash Flow cannot join shared accounts.');
    } else if (!cloud.signedIn) {
      body = message(
        Icons.group_add_outlined,
        'You have been invited',
        'Sign in with Google to see the invitation. Your books are saved online, so they are not lost with your phone.',
        SizedBox(width: 280, child: GoogleButton(onPressed: () => _signIn(cloud))),
      );
    } else {
      body = FutureBuilder<CodeDetails?>(
        future: _details,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (snap.hasError) {
            return message(Icons.cloud_off_outlined, 'No connection', 'Opening an invitation needs the internet. Try again when you are online.');
          }
          if (d == null) {
            return message(Icons.link_off_rounded, 'Invitation not found', 'Ask the person who shared it for a new QR code.');
          }
          if (d.alreadyMember) {
            return message(
              Icons.check_circle_outline_rounded,
              'You are already in "${d.accountName}"',
              'It is in your accounts.',
              FilledButton(onPressed: () => openAccount(context, d.accountId), child: const Text('Open it')),
            );
          }
          if (!d.usable) {
            return message(Icons.timer_off_outlined, 'This invitation has ended', 'It expired or was stopped. Ask ${d.invitedBy.isEmpty ? 'the owner' : d.invitedBy} for a new QR code.');
          }
          final who = d.invitedBy.isEmpty ? 'Someone' : d.invitedBy;
          return message(
            Icons.group_add_outlined,
            'Join "${d.accountName}"?',
            '$who shared it with you. ${d.role.label}: '
                '${d.role.canEdit ? 'you can add, change and delete entries.' : 'you can see every entry, but not change them.'}',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: _joining ? null : () => context.go(Routes.home), child: const Text('Not now')),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _joining ? null : () => _join(cloud, d),
                  child: Text(_joining ? 'Joining…' : 'Accept'),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Invitation')), body: body);
  }
}
