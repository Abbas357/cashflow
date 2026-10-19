import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import 'profile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _currency(BuildContext context, SettingsController s) async {
    final v = await promptText(
      context,
      title: 'Currency symbol',
      initial: s.currency,
      label: 'For example Rs, PKR, \$, AED. Leave empty for none.',
    );
    if (v != null) await s.setCurrency(v);
  }

  Future<void> _wipe(BuildContext context) async {
    final ledger = context.read<LedgerController>();
    final ok = await confirm(
      context,
      title: 'Delete all data?',
      message: 'Every account, entry and history record on this device will be erased. '
          'This cannot be undone.',
      confirmLabel: 'Delete everything',
    );
    if (!ok) return;
    await ledger.repo.wipe();
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
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Currency symbol'),
                subtitle: Text(s.currency.isEmpty ? 'None' : s.currency),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _currency(context, s),
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered_rounded),
                title: const Text('Number grouping'),
                subtitle: Text(s.grouping == NumberGrouping.lakh ? 'Lakh: 4,78,940' : 'Million: 478,940'),
                trailing: DropdownButton<NumberGrouping>(
                  value: s.grouping,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: NumberGrouping.lakh, child: Text('Lakh')),
                    DropdownMenuItem(value: NumberGrouping.million, child: Text('Million')),
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
          const SizedBox(height: 8),
          Text('Cash Flow 1.0.0', style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
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
