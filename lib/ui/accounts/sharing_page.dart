import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../widgets/common.dart';
import 'contact_picker.dart';

/// Who can see an account, and what they may do.
///
/// People are added from the phone's contacts (or by number on desktop)
/// as Can edit or View only. While the app is offline-only the invites
/// wait here as "Pending"; once cloud sync is on they are delivered to
/// whoever signs in with that number.
class SharingPage extends StatefulWidget {
  final Account account;

  const SharingPage({super.key, required this.account});

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  List<AccountMember>? _members;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await context.read<LedgerController>().repo.members(widget.account.id);
    if (mounted) setState(() => _members = m);
  }

  Future<void> _add() async {
    final picked = await pickPeople(context);
    if (picked == null || picked.people.isEmpty || !mounted) return;
    final ledger = context.read<LedgerController>();
    for (final p in picked.people) {
      await ledger.repo.invite(
        accountId: widget.account.id,
        name: p.name,
        phone: p.phone,
        role: picked.role,
      );
    }
    await ledger.changed();
    await _load();
    if (mounted) {
      toast(context, '${picked.people.length} invite(s) saved. They go out when cloud sync is on.');
    }
  }

  Future<void> _setRole(AccountMember m, AccountRole role) async {
    await context.read<LedgerController>().repo.setMemberRole(m.id, role);
    await _load();
  }

  Future<void> _remove(AccountMember m) async {
    final ok = await confirm(
      context,
      title: 'Remove ${m.displayName.isEmpty ? m.phone : m.displayName}?',
      message: 'They will no longer see "${widget.account.name}".',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    final ledger = context.read<LedgerController>();
    await ledger.repo.removeMember(m);
    await ledger.changed();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = context.cash;
    final canManage = widget.account.role.canManage;
    final members = _members;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share account'),
            Text(widget.account.name, style: t.labelSmall),
          ],
        ),
      ),
      body: members == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_off_outlined, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cash Flow works fully offline. Invites are saved on this '
                          'device and sent once cloud sync is switched on. The '
                          'person signs in with that mobile number, accepts the '
                          'invitation, and from then on sees every entry and each '
                          'change, including the old value.',
                          style: t.bodySmall?.copyWith(color: scheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('People', style: t.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 72, color: c.hairline),
                        _MemberTile(
                          member: members[i],
                          canManage: canManage && members[i].role != AccountRole.owner,
                          onRole: (r) => _setRole(members[i], r),
                          onRemove: () => _remove(members[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (canManage)
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.contacts_outlined),
                    label: const Text('Share with contacts'),
                  ),
                const SizedBox(height: 20),
                Text('What each role can do', style: t.titleSmall),
                const SizedBox(height: 8),
                const _RoleHelp(
                  icon: Icons.edit_outlined,
                  title: 'Can edit',
                  text: 'Add, change and delete entries. Every change is logged with the previous value.',
                ),
                const _RoleHelp(
                  icon: Icons.visibility_outlined,
                  title: 'View only',
                  text: 'See every entry, the totals, reports and the change history, but cannot change anything.',
                ),
              ],
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final AccountMember member;
  final bool canManage;
  final ValueChanged<AccountRole> onRole;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = member.displayName.isEmpty ? member.phone : member.displayName;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.role == AccountRole.owner
            ? AppTheme.brandColor
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: member.role == AccountRole.owner ? Colors.white : null,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
      ),
      title: Text(name),
      subtitle: Text(
        [
          if (member.phone.isNotEmpty && member.displayName.isNotEmpty) member.phone,
          if (member.isPending) 'Invited, waiting for them to accept',
          if (member.status == MemberStatus.declined) 'Declined',
        ].join('  ·  ').ifEmpty(member.role.label),
        style: t.bodySmall,
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Change access',
              onSelected: (v) => v == 'remove' ? onRemove() : onRole(AccountRole.parse(v)),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: AccountRole.editor.name,
                  checked: member.role == AccountRole.editor,
                  child: const Text('Can edit'),
                ),
                CheckedPopupMenuItem(
                  value: AccountRole.viewer.name,
                  checked: member.role == AccountRole.viewer,
                  child: const Text('View only'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(member.role.label, style: t.labelLarge),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            )
          : Text(member.role.label, style: t.labelLarge),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _RoleHelp extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RoleHelp({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.cash.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$title. ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: text),
                ],
              ),
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
