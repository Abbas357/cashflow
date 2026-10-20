import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../services/cloud_sync.dart';
import '../../state/ledger_controller.dart';
import '../accounts/sharing_page.dart';
import '../widgets/common.dart';
import 'invite_widgets.dart';

/// Everything about sharing in one place, for people signed in with
/// Google: invitations waiting for an answer, accounts others shared with
/// you, and the people you shared yours with: whether they accepted, their
/// role, and how many entries they have made.
class SharingHubPage extends StatelessWidget {
  const SharingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSync?>();
    final ledger = context.watch<LedgerController>();
    final t = Theme.of(context).textTheme;
    final invitations = cloud?.invitations ?? const <Invitation>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharing'),
        actions: [
          if (canScanInvites)
            IconButton(
              tooltip: 'Scan QR code',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () => scanInvite(context),
            ),
          IconButton(
            tooltip: 'Check for changes',
            icon: const Icon(Icons.sync_rounded),
            onPressed: cloud?.sync,
          ),
        ],
      ),
      body: PageBody(
        maxWidth: 760,
        children: [
          Text('Invitations for you', style: t.titleMedium),
          const SizedBox(height: 8),
          if (invitations.isEmpty)
            Text(
              'None waiting. When someone shares an account with your Google address, it shows here and on the home screen.',
              style: t.bodySmall,
            )
          else
            for (final i in invitations)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: InvitationCard(invitation: i)),
          if (canScanInvites) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => scanInvite(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR code'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Overview(key: ValueKey(ledger.revision), uid: cloud?.user?.id),
        ],
      ),
    );
  }
}

/// One shared account and its people, read from this device's copy.
class _Shared {
  final Account account;
  final List<AccountMember> members;
  final Map<String, (int, DateTime?)> entries;
  const _Shared(this.account, this.members, this.entries);

  AccountMember? get owner => members.where((m) => m.role == AccountRole.owner).firstOrNull;
  List<AccountMember> get others => [for (final m in members) if (m.role != AccountRole.owner) m];
}

class _Overview extends StatefulWidget {
  final String? uid;

  const _Overview({super.key, required this.uid});

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  late final Future<List<_Shared>> _load = _read();

  Future<List<_Shared>> _read() async {
    final ledger = context.read<LedgerController>();
    final out = <_Shared>[];
    for (final a in ledger.accounts) {
      final members = await ledger.repo.members(a.id);
      if (a.role == AccountRole.owner && members.every((m) => m.role == AccountRole.owner)) continue;
      out.add(_Shared(a, members, await ledger.repo.entriesBy(a.id)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<_Shared>>(
      future: _load,
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final all = snap.data!;
        final withMe = [for (final s in all) if (s.account.role != AccountRole.owner) s];
        final mine = [for (final s in all) if (s.account.role == AccountRole.owner) s];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shared with you', style: t.titleMedium),
            const SizedBox(height: 8),
            if (withMe.isEmpty)
              Text('No accounts yet.', style: t.bodySmall)
            else
              Card(
                child: Column(
                  children: [
                    for (final s in withMe)
                      ListTile(
                        leading: const Icon(Icons.folder_shared_outlined),
                        title: Text(s.account.name),
                        subtitle: Text(
                          [
                            'From ${s.owner?.label ?? 'the owner'}',
                            s.account.role.label,
                            _entries(s.entries[widget.uid], you: true),
                          ].join(', '),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => openAccount(context, s.account.id),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Text('People you shared with', style: t.titleMedium),
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(
                'You have not shared an account yet. Open Accounts, choose one, then Share, '
                'and invite someone by their Gmail address or a QR code.',
                style: t.bodySmall,
              )
            else
              for (final s in mine) ...[
                _AccountPeople(shared: s),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

String _entries((int, DateTime?)? e, {bool you = false}) {
  final n = e?.$1 ?? 0;
  if (n == 0) return you ? 'no entries by you yet' : 'no entries yet';
  final last = e!.$2 == null ? '' : ', last ${Fmt.dayShort(e.$2!)}';
  return '$n ${n == 1 ? 'entry' : 'entries'}${you ? ' by you' : ''}$last';
}

class _AccountPeople extends StatelessWidget {
  final _Shared shared;

  const _AccountPeople({required this.shared});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cash;
    final people = shared.others;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(shared.account.name, style: t.titleSmall)),
                TextButton.icon(
                  onPressed: () => openSharing(context, shared.account),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
          ),
          for (final (i, m) in people.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 72, color: c.hairline),
            ListTile(
              leading: CircleAvatar(child: Text(m.label.isEmpty ? '?' : m.label[0].toUpperCase())),
              title: Text(m.label),
              subtitle: Text(
                [
                  if (m.email.isNotEmpty && m.email != m.label) m.email,
                  switch (m.status) {
                    MemberStatus.pending => 'Invited, has not answered yet',
                    MemberStatus.declined => 'Declined',
                    MemberStatus.active => _entries(shared.entries[m.userId]),
                  },
                ].join('\n'),
              ),
              isThreeLine: m.email.isNotEmpty && m.email != m.label,
              trailing: _StatusChip(m),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AccountMember member;

  const _StatusChip(this.member);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (text, color) = switch (member.status) {
      MemberStatus.active => (member.role.label, scheme.primary),
      MemberStatus.pending => ('Waiting', context.cash.muted),
      MemberStatus.declined => ('Declined', AppTheme.errorColor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: t.labelSmall?.copyWith(color: color)),
    );
  }
}
