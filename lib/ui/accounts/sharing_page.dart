import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../services/cloud_sync.dart';
import '../../services/notifier.dart';
import '../../state/ledger_controller.dart';
import '../navigation/profile_footer.dart';
import '../sharing/invite_widgets.dart';
import '../widgets/common.dart';
import '../widgets/google_button.dart';

/// Who can see an account, and what they may do.
///
/// People sign in with Google, so they are invited by their Gmail address
/// (they see the invitation when they open the app) or by a QR code they
/// scan. Either way they choose to accept, and get Can edit or View only.
class SharingPage extends StatefulWidget {
  final Account account;

  const SharingPage({super.key, required this.account});

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  AccountRole _role = AccountRole.editor;
  String? _emailError;
  List<AccountMember>? _members;
  Map<String, (int, DateTime?)> _entries = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<LedgerController>().repo;
    final m = await repo.members(widget.account.id);
    final e = await repo.entriesBy(widget.account.id);
    if (mounted) {
      setState(() {
        _members = m;
        _entries = e;
      });
    }
  }

  Future<void> _invite(CloudSync cloud) async {
    final address = _email.text.trim().toLowerCase();
    String? problem;
    if (!_emailShape.hasMatch(address)) {
      problem = 'Type an email address, like ali.khan@gmail.com';
    } else if (address == cloud.email?.toLowerCase()) {
      problem = 'That is your own address';
    } else if (_members!.any((m) => m.email == address && m.status == MemberStatus.active)) {
      problem = 'They already have access';
    }
    setState(() => _emailError = problem);
    if (problem != null) return;

    final ledger = context.read<LedgerController>();
    await ledger.repo.inviteByEmail(accountId: widget.account.id, email: address, role: _role);
    await ledger.changed();
    _email.clear();
    await _load();
    // So they hear when the other side adds entries.
    await Notifier.requestPermission();
    if (mounted) {
      toast(context, 'Invitation sent to $address. They will see it when they open Cash Flow.');
    }
  }

  Future<void> _setRole(AccountMember m, AccountRole role) async {
    final ledger = context.read<LedgerController>();
    await ledger.repo.setMemberRole(m.id, role);
    await ledger.changed();
    await _load();
  }

  Future<void> _remove(AccountMember m) async {
    final ok = await confirm(
      context,
      title: m.isPending ? 'Cancel the invitation to ${m.label}?' : 'Remove ${m.label}?',
      message: m.isPending
          ? 'They will no longer see the invitation.'
          : 'They will no longer see "${widget.account.name}". Entries they made stay.',
      confirmLabel: m.isPending ? 'Cancel invitation' : 'Remove',
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
    final cloud = context.watch<CloudSync?>();
    final signedIn = cloud?.signedIn ?? false;
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
                if (!signedIn) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in with Google to share this account. The people you share it '
                          'with sign in too, and see every entry on their phone or the web. '
                          'Your books are also saved online, so they are not lost.',
                          style: t.bodyMedium,
                        ),
                        if (cloud != null) ...[
                          const SizedBox(height: 12),
                          GoogleButton(onPressed: () => signInWithGoogle(context, cloud)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (canManage) ...[
                  Text('Invite someone', style: t.titleMedium),
                  const SizedBox(height: 10),
                  SegmentedButton<AccountRole>(
                    segments: const [
                      ButtonSegment(value: AccountRole.editor, icon: Icon(Icons.edit_outlined), label: Text('Can edit')),
                      ButtonSegment(value: AccountRole.viewer, icon: Icon(Icons.visibility_outlined), label: Text('View only')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (v) => setState(() => _role = v.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _invite(cloud!),
                    onChanged: (_) {
                      if (_emailError != null) setState(() => _emailError = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Their Gmail address',
                      hintText: 'ali.khan@gmail.com',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _invite(cloud!),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send invitation'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showInviteQr(context, widget.account, _role),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Show QR code to scan'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'By email: they see the invitation when they open Cash Flow and accept it. '
                    'By QR code: they scan it on their phone, there and then.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 24),
                ],
                Text('People', style: t.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 72, color: c.hairline),
                        _MemberTile(
                          member: members[i],
                          entries: _entries[members[i].userId],
                          canManage: canManage && members[i].role != AccountRole.owner,
                          onRole: (r) => _setRole(members[i], r),
                          onRemove: () => _remove(members[i]),
                        ),
                      ],
                    ],
                  ),
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
  final (int, DateTime?)? entries;
  final bool canManage;
  final ValueChanged<AccountRole> onRole;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.entries,
    required this.canManage,
    required this.onRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = member.label;
    final n = entries?.$1 ?? 0;
    final status = switch (member.status) {
      MemberStatus.pending => 'Invited, has not answered yet',
      MemberStatus.declined => 'Declined',
      MemberStatus.active => n == 0
          ? 'No entries yet'
          : '$n ${n == 1 ? 'entry' : 'entries'}${entries!.$2 == null ? '' : ', last ${Fmt.dayShort(entries!.$2!)}'}',
    };
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
        [if (member.email.isNotEmpty && member.email != name) member.email, status].join('\n'),
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
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    member.isPending ? 'Cancel invitation' : 'Remove',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
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
