import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/cloud_config.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/cloud_sync.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/google_button.dart';

/// The foot of the menu: who you are and where your books are.
///
/// Signed out, it reads "Offline, saved on this device" with a Continue
/// with Google button under it. Signed in, it shows your Google name and
/// photo and how syncing is going; tapping opens Sync now, Settings and
/// Sign out.
class ProfileFooter extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onOpen;

  const ProfileFooter({super.key, this.collapsed = false, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final cloud = context.watch<CloudSync?>();
    final t = Theme.of(context).textTheme;
    final account = cloud != null && cloud.signedIn ? cloud : null;
    final name = account?.name ?? (s.name.isEmpty ? 'You' : s.name);
    final status = account == null ? 'Offline, saved on this device' : _status(account);
    final avatar = _Avatar(name: name, photo: account?.avatarUrl);

    void settings() {
      onOpen?.call();
      context.go(Routes.settings);
    }

    if (collapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) => Tooltip(
              message: '$name: $status',
              child: IconButton(
                onPressed: account == null ? settings : () => _accountMenu(context, account),
                icon: avatar,
              ),
            ),
          ),
          if (cloud != null && account == null)
            Tooltip(
              message: 'Continue with Google',
              child: IconButton(
                onPressed: () => _signIn(context, cloud),
                icon: const GoogleLogo(size: 20),
              ),
            ),
        ],
      );
    }

    final who = Builder(
      builder: (context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: account == null ? settings : () => _accountMenu(context, account),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    Text(status, style: t.labelSmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (account != null) _SyncIcon(account),
            ],
          ),
        ),
      ),
    );

    if (cloud == null || account != null) return who;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        who,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
          child: GoogleButton(onPressed: () => _signIn(context, cloud)),
        ),
      ],
    );
  }

  static String _changes(int n) => '$n ${n == 1 ? 'change' : 'changes'}';

  static String _status(CloudSync c) => switch (c.status) {
    SyncState.syncing => 'Syncing…',
    SyncState.offline =>
      c.pending > 0 ? 'Offline, ${_changes(c.pending)} waiting' : 'Offline, saved on this device',
    SyncState.failed => 'Sync paused, tap for details',
    _ => c.pending > 0 ? '${_changes(c.pending)} to sync' : 'Synced to the cloud',
  };

  Future<void> _signIn(BuildContext context, CloudSync cloud) async {
    if (!cloud.available) {
      toast(context, 'Cloud sign-in is not set up in this build yet');
      return;
    }
    if (!CloudConfig.signInSupported) {
      toast(context, 'Sign in on the web or the Android app. This desktop app keeps its books on this device.');
      return;
    }
    try {
      await cloud.signIn();
    } catch (_) {
      if (context.mounted) toast(context, 'Could not open Google sign-in. Check the connection and try again.');
    }
  }

  Future<void> _accountMenu(BuildContext context, CloudSync cloud) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(Offset.zero, ancestor: overlay);
    final t = Theme.of(context).textTheme;
    final problem = cloud.status == SyncState.failed || cloud.status == SyncState.offline ? cloud.error : null;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(at.dx, at.dy, box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cloud.name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (cloud.email != null) Text(cloud.email!, style: t.bodySmall),
              if (problem != null) ...[
                const SizedBox(height: 6),
                Text(problem, style: t.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'sync',
          child: ListTile(leading: Icon(Icons.sync_rounded), title: Text('Sync now'), contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'), contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'out',
          child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Sign out'), contentPadding: EdgeInsets.zero),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'sync':
        await cloud.sync();
      case 'settings':
        onOpen?.call();
        context.go(Routes.settings);
      case 'out':
        final waiting = cloud.pending;
        final lost = waiting == 0
            ? ''
            : ' ${_changes(waiting)} ${waiting == 1 ? 'has' : 'have'} not reached the cloud yet '
                'and will be lost if this device is offline.';
        final ok = await confirm(
          context,
          title: 'Sign out?',
          message: 'Your books stay in the cloud and come back when you sign in again. '
              'The copy on this device is removed.$lost',
          confirmLabel: 'Sign out',
          destructive: waiting > 0,
        );
        if (ok) await cloud.signOut();
    }
  }
}

/// Your Google photo, or your initial while it loads or when offline.
class _Avatar extends StatelessWidget {
  final String name;
  final String? photo;

  const _Avatar({required this.name, this.photo});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 15,
    backgroundColor: AppTheme.brandColor,
    foregroundColor: Colors.white,
    foregroundImage: photo == null ? null : NetworkImage(photo!),
    onForegroundImageError: photo == null ? null : (_, _) {},
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

/// A small mark for how syncing is going.
class _SyncIcon extends StatelessWidget {
  final CloudSync cloud;

  const _SyncIcon(this.cloud);

  @override
  Widget build(BuildContext context) {
    final muted = context.cash.muted;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: switch (cloud.status) {
        SyncState.syncing => SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: muted),
        ),
        SyncState.offline => Icon(Icons.cloud_off_outlined, size: 18, color: muted),
        SyncState.failed => Icon(Icons.sync_problem_rounded, size: 18, color: context.cash.outText),
        _ => Icon(Icons.cloud_done_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
      },
    );
  }
}
