import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../services/cloud_sync.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'invite_widgets.dart';

/// The bell in the top bar, with how many things are unread: changes
/// other people made to shared accounts, and invitations.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<CloudSync?>()?.unread ?? 0;
    return IconButton(
      tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
      onPressed: () => context.go(Routes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppTheme.errorColor,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded),
      ),
    );
  }
}

/// What other people did in shared accounts, newest first. Unread ones
/// stand out; a tap marks one read and opens its account, and all can be
/// marked read at once. Invitations waiting for an answer come first.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<EntryChange>>? _changes;
  int _seen = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ledger = context.watch<LedgerController>();
    final me = context.read<CloudSync?>()?.user?.id;
    // Reload when new changes arrive while the page is open.
    if (ledger.revision != _seen && me != null) {
      _seen = ledger.revision;
      _changes = ledger.repo.changesByOthers(me);
    }
  }

  Future<void> _open(EntryChange c) async {
    await context.read<CloudSync>().markRead(c.id);
    if (mounted) await openAccount(context, c.accountId);
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSync?>();
    final invitations = cloud?.invitations ?? const <Invitation>[];
    final names = {for (final a in context.watch<LedgerController>().accounts) a.id: a.name};
    final anyUnread = (cloud?.settings.unreadChanges.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: anyUnread ? cloud!.markAllRead : null,
            child: const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<EntryChange>>(
        future: _changes,
        builder: (context, snap) {
          final changes = snap.data ?? const <EntryChange>[];
          if (snap.connectionState != ConnectionState.done && changes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (changes.isEmpty && invitations.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              message: 'When someone you share an account with adds, edits or deletes an entry, it shows here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MaxWidthColumn(
                children: [
                  for (final i in invitations)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: InvitationCard(invitation: i)),
                  for (final c in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ChangeTile(
                        change: c,
                        account: names[c.accountId] ?? 'A shared account',
                        unread: cloud?.isUnread(c.id) ?? false,
                        onTap: () => _open(c),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps the list a readable width on desktop.
class MaxWidthColumn extends StatelessWidget {
  final List<Widget> children;

  const MaxWidthColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

class _ChangeTile extends StatelessWidget {
  final EntryChange change;
  final String account;
  final bool unread;
  final VoidCallback onTap;

  const _ChangeTile({
    required this.change,
    required this.account,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = context.cash;
    final radius = BorderRadius.circular(14);
    final data = change.after ?? change.before ?? const <String, Object?>{};
    final isIn = data['type'] == 'in';
    final amount = data['amount'] is num ? Fmt.money(data['amount'] as num) : '';
    final note = (data['note'] as String? ?? '').trim();
    final who = change.changedByName.trim().isEmpty ? 'Someone' : change.changedByName.trim();
    final (icon, did) = switch (change.action) {
      ChangeAction.created => (Icons.add_circle_outline_rounded, 'added'),
      ChangeAction.updated => (Icons.edit_outlined, 'edited'),
      ChangeAction.deleted => (Icons.delete_outline_rounded, 'deleted'),
    };
    final was = change.before?['amount'];
    final moved = change.action == ChangeAction.updated && was is num && was != change.after?['amount']
        ? ' (was ${Fmt.money(was)})'
        : '';

    return Material(
      color: unread ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: unread ? scheme.primary.withValues(alpha: 0.2) : c.hairline),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isIn ? c.inText : c.outText).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: isIn ? c.inText : c.outText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$who $did ${isIn ? 'Cash In' : 'Cash Out'} $amount$moved${note.isEmpty ? '' : ': $note'}',
                      style: t.bodyMedium?.copyWith(
                        height: 1.35,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$account · ${Fmt.stamp(change.changedAt)}', style: t.bodySmall),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
