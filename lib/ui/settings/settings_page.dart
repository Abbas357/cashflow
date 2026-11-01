import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/cloud_sync.dart';
import '../../services/install_report.dart';
import '../../services/notifier.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/currency_picker.dart';
import 'profile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _currency(BuildContext context, SettingsController s) async {
    final v = await promptText(
      context,
      title: 'Currency symbol',
      initial: s.currency,
      label: 'For example Rs, PKR, \$, €. Leave empty for none.',
    );
    if (v != null) await s.setCurrency(v);
  }

  Future<void> _wipe(BuildContext context) async {
    final ledger = context.read<LedgerController>();
    final synced = context.read<CloudSync?>()?.signedIn ?? false;
    final ok = await confirm(
      context,
      title: 'Delete all data?',
      message: 'Every account, entry and history record '
          '${synced ? 'on this device and in the cloud' : 'on this device'} will be erased. '
          'This cannot be undone.',
      confirmLabel: 'Delete everything',
    );
    if (!ok) return;
    if (synced) {
      // Marked deleted rather than erased, so the deletion syncs to the
      // cloud and every other device signed in.
      for (final a in ledger.accounts.where((a) => a.role.canManage)) {
        await ledger.repo.deleteAccount(a.id);
      }
    } else {
      await ledger.repo.wipe();
    }
    await ledger.reload();
    if (context.mounted) toast(context, 'All data deleted');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        maxWidth: 680,
        children: [
          _Group(
            title: 'Profile',
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Your name and address'),
                subtitle: Text(s.name.isEmpty ? 'Not set' : s.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openAdaptive(context, const ProfilePage(), height: 560),
              ),
            ],
          ),
          _Group(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
              ),
            ],
          ),
          _Group(
            title: 'Numbers',
            children: [
              const ListTile(
                leading: Icon(Icons.payments_outlined),
                title: Text('Currency'),
                subtitle: Text('Type to search by name or code'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CurrencyPicker(settings: s),
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('Symbol shown'),
                subtitle: Text(s.currency.isEmpty ? 'None' : 'Example: ${Fmt.money(478940)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _currency(context, s),
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered_rounded),
                title: const Text('Number grouping'),
                subtitle: const Text('Set by the currency; change it if you write numbers differently'),
                trailing: DropdownButton<NumberGrouping>(
                  value: s.grouping,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final g in NumberGrouping.values)
                      DropdownMenuItem(
                        value: g,
                        child: Text(g.example, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                  ],
                  onChanged: (v) => v == null ? null : s.setGrouping(v),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.exposure_outlined),
                title: const Text('Always show decimals'),
                subtitle: Text('Example: ${Fmt.money(1250.5)}'),
                value: s.decimals == 2,
                onChanged: (v) => s.setDecimals(v ? 2 : 0),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week_outlined),
                title: const Text('Week starts on'),
                trailing: DropdownButton<int>(
                  value: s.weekStart,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
                    DropdownMenuItem(value: DateTime.saturday, child: Text('Saturday')),
                    DropdownMenuItem(value: DateTime.sunday, child: Text('Sunday')),
                  ],
                  onChanged: (v) => v == null ? null : s.setWeekStart(v),
                ),
              ),
            ],
          ),
          if (Notifier.supported && (context.watch<CloudSync?>()?.signedIn ?? false))
            _Group(
              title: 'Notifications',
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Changes in shared accounts'),
                  subtitle: const Text('When someone you share with adds, edits or deletes an entry'),
                  value: s.notifyChanges,
                  onChanged: (v) async {
                    final cloud = context.read<CloudSync?>();
                    await s.setNotifyChanges(v);
                    await cloud?.updatePush();
                    if (v && !await Notifier.requestPermission() && context.mounted) {
                      toast(context, 'Allow notifications for Cash Flow in your phone or browser settings.');
                    }
                  },
                ),
              ],
            ),
          _Group(
            title: 'Usage statistics',
            children: [
              _UsageStats(settings: s),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.privacyPolicy),
              ),
            ],
          ),
          _Group(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.errorColor),
                title: const Text('Delete all data', style: TextStyle(color: AppTheme.errorColor)),
                subtitle: const Text('Erase everything on this device'),
                onTap: () => _wipe(context),
              ),
            ],
          ),
          if (context.watch<CloudSync?>()?.signedIn ?? false)
            _Group(
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: AppTheme.errorColor),
                  title: const Text('Delete account', style: TextStyle(color: AppTheme.errorColor)),
                  subtitle: const Text('Remove your account and data from Cash Flow for good'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.deleteAccount),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text('Cash Flow 1.0.0', style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// What this install sends to count users per country, and a way to delete it.
class _UsageStats extends StatefulWidget {
  final SettingsController settings;

  const _UsageStats({required this.settings});

  @override
  State<_UsageStats> createState() => _UsageStatsState();
}

class _UsageStatsState extends State<_UsageStats> {
  bool _deleting = false;

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this information?',
      message: 'It will be removed from the cloud, and this device will stop sending it. '
          'Your accounts and entries are not affected.',
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    var deleted = false;
    try {
      await InstallReport.delete(widget.settings);
      deleted = true;
    } catch (_) {
      // Told below.
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    toast(context, deleted ? 'Deleted' : 'Could not delete. Check the connection and try again.');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    if (s.installStatsOff) {
      return const ListTile(
        leading: Icon(Icons.bar_chart_rounded),
        title: Text('Deleted'),
        subtitle: Text('This device no longer sends information for counting users per country.'),
      );
    }
    final t = Theme.of(context).textTheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: t.bodySmall)),
          Expanded(child: SelectableText(value, style: t.bodyMedium)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.bar_chart_rounded),
          title: const Text('Counting users per country'),
          subtitle: Text(
            '${s.installReported != null ? 'Sent' : 'Not sent yet'}: only this, never your name or entries.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              row('Random ID', s.installId),
              row('Country', s.country ?? 'Not detected'),
              row('Currency', s.currencyInfo.code),
              row('Device', InstallReport.platform),
            ],
          ),
        ),
        ListTile(
          enabled: !_deleting,
          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
          title: const Text('Delete this information', style: TextStyle(color: AppTheme.errorColor)),
          subtitle: const Text('Also stops this device sending it'),
          onTap: _delete,
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 1.1)),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
