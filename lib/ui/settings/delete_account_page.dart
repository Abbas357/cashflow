import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/cloud_config.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/cloud_sync.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../entry/attachments.dart';
import '../navigation/profile_footer.dart';
import '../widgets/common.dart';
import '../widgets/google_button.dart';

/// Deletes the signed-in person's account, as Google Play requires. Reached
/// from Settings, the menu's account popup and, on the web, the public page
/// in `web/delete-account`, which works without the app installed.
///
/// Signed out, it asks to sign in with Google first and comes back here.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const _word = 'DELETE';

  final _typed = TextEditingController();
  late final Future<List<String>> _shared = context.read<LedgerController>().repo.sharedAccountNames();
  bool _deleting = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _signIn(CloudSync cloud) async {
    await context.read<SettingsController>().setPendingDeleteAccount(true);
    if (mounted) await signInWithGoogle(context, cloud);
  }

  Future<void> _delete(CloudSync cloud) async {
    setState(() => _deleting = true);
    try {
      await cloud.deleteAccount();
      await Attachments.deleteAll();
      if (!mounted) return;
      toast(context, 'Your account and data have been deleted');
      context.go(Routes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      toast(context, 'Could not delete your account, and nothing was removed. Check the connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSync?>();
    final Widget body;
    if (cloud != null && (cloud.signedIn || _deleting)) {
      body = _confirmation(context, cloud);
    } else if (cloud == null || !cloud.available || !CloudConfig.signInSupported) {
      body = const EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Sign in on the web or the Android app',
        message: 'Accounts are deleted after signing in with Google, which this version of Cash Flow cannot do. '
            'Its books stay on this device: Settings, Delete all data erases them.',
      );
    } else {
      body = EmptyState(
        icon: Icons.person_remove_outlined,
        title: 'Sign in to delete your account',
        message: 'Sign in with the Google account you use in Cash Flow. You will be asked to confirm before anything is deleted.',
        action: SizedBox(width: 280, child: GoogleButton(onPressed: () => _signIn(cloud))),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Delete account')), body: body);
  }

  Widget _confirmation(BuildContext context, CloudSync cloud) {
    final t = Theme.of(context).textTheme;
    return PageBody(
      maxWidth: 680,
      children: [
        Text(
          'This permanently deletes the Cash Flow account of ${cloud.email ?? cloud.name}. It cannot be undone.',
          style: t.titleMedium,
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: 'What is deleted',
          child: _Points([
            'Your accounts, entries and change history, in the cloud and on this device.',
            'The Google details Cash Flow holds: your name, email address, photo and sign-in.',
            'Your profile, settings and receipt photos on this device.',
            'Your place in accounts other people shared with you, and invitations sent to you.',
          ]),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _shared,
          builder: (context, snap) {
            final names = snap.data ?? const <String>[];
            if (names.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                title: 'People you share with lose access',
                child: Text(
                  'These accounts are deleted for everyone in them: ${names.join(', ')}.',
                  style: t.bodyMedium,
                ),
              ),
            );
          },
        ),
        const SectionCard(
          title: 'What stays',
          child: _Points([
            'Entries you added to accounts other people own stay in their books, shown as made by "Deleted user".',
            'Your Google account itself. Only its link to Cash Flow is removed.',
            'A copy on another phone or browser stays there until you use Delete all data on it or remove the app.',
          ]),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _deleting ? null : () => context.push(Routes.backup),
            icon: const Icon(Icons.save_alt_rounded),
            label: const Text('Save a backup first'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _typed,
          enabled: !_deleting,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Type $_word to confirm'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _deleting || _typed.text.trim().toUpperCase() != _word ? null : () => _delete(cloud),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(_deleting ? 'Deleting…' : 'Delete my account permanently'),
        ),
      ],
    );
  }
}

class _Points extends StatelessWidget {
  final List<String> points;

  const _Points(this.points);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: t.bodyMedium),
                Expanded(child: Text(p, style: t.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
