import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currencies.dart';
import '../../core/utils/formatters.dart';
import '../../services/cloud_sync.dart';
import '../../services/notifier.dart';
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
                child: _CurrencyPicker(settings: s),
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
                    await s.setNotifyChanges(v);
                    if (v && !await Notifier.requestPermission() && context.mounted) {
                      toast(context, 'Allow notifications for Cash Flow in your phone or browser settings.');
                    }
                  },
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

/// Every currency in a dropdown that filters as you type. Focusing it
/// selects the current name, so typing replaces it and searches.
class _CurrencyPicker extends StatefulWidget {
  final SettingsController settings;

  const _CurrencyPicker({required this.settings});

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  final _text = TextEditingController();

  static String _label(Currency c) => '${c.name} (${c.code})';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.settings.currencyInfo;
    return Focus(
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
      },
      child: DropdownMenu<String>(
        key: ValueKey(current.code),
        controller: _text,
        initialSelection: current.code,
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 360,
        leadingIcon: SizedBox(
          width: 48,
          child: Center(child: Text(current.symbol, style: const TextStyle(fontWeight: FontWeight.w600))),
        ),
        dropdownMenuEntries: [
          for (final c in currencies)
            DropdownMenuEntry(
              value: c.code,
              label: _label(c),
              trailingIcon: Text(c.symbol),
            ),
        ],
        onSelected: (code) {
          if (code != null) widget.settings.setCurrencyCode(code);
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
