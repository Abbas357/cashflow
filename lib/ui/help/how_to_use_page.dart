import 'package:flutter/material.dart';

import '../widgets/common.dart';

class _Topic {
  final IconData icon;
  final String title;
  final List<String> steps;
  const _Topic(this.icon, this.title, this.steps);
}

const _topics = [
  _Topic(Icons.folder_open_rounded, 'Accounts', [
    'An account is a separate book, such as Home Expenses or Construction.',
    'Tap the account name at the top of the main screen to switch, search or add accounts.',
    'Tap Edit in that list to rename, share or delete an account.',
    'Open Accounts from the menu to reorder them by dragging.',
  ]),
  _Topic(Icons.add_circle_outline_rounded, 'Adding entries', [
    'Tap the green Cash In button for money received, or the red Cash Out button for money spent.',
    'Type the amount. You can type sums like 250+120 or open the calculator.',
    'Add a note. Notes you used before are suggested as you type.',
    'Use the arrows beside the date to move a day back or forward, or tap it to pick any date.',
    'Save and continue keeps the form open for the next entry. Save and exit goes back.',
    'On a computer: Ctrl+I opens Cash In, Ctrl+O opens Cash Out, Ctrl+Enter saves.',
  ]),
  _Topic(Icons.edit_note_rounded, 'Editing and history', [
    'Tap any entry to see its details, the balance after it, and its full history.',
    'Edit or delete it from there. The old value is always kept in the history.',
    'Activity log in the menu lists every change across your accounts.',
  ]),
  _Topic(Icons.filter_alt_outlined, 'Finding entries', [
    'Use All, Daily, Weekly, Monthly or Yearly under the title, then the arrows to move between periods.',
    'Tap the period name to jump to a date. The three dot menu has Select date range.',
    'Search with the magnifier icon. It matches notes and amounts.',
    'The three dot menu also sorts by notes or date, oldest or newest first.',
  ]),
  _Topic(Icons.insights_outlined, 'Reports', [
    'Insights shows monthly charts, your balance trend, where the money went and the biggest expenses.',
    'Summary totals each day, month or year with the closing balance.',
    'Account summary compares all accounts at a glance.',
    'Reports: all accounts builds a PDF or CSV for any dates, and Print sends the current view to a printer.',
    'Set your name and address in Settings so they appear on printed reports.',
  ]),
  _Topic(Icons.swap_horiz_rounded, 'Transfers', [
    'Transfer moves money from one account to another.',
    'It writes a Cash Out and a matching Cash In. Changing one side changes both.',
  ]),
  _Topic(Icons.group_outlined, 'Sharing', [
    'Open an account in Accounts and choose Share.',
    'Pick people from your contacts, or type a number, and choose Can edit or View only.',
    'Invites are kept on this device and sent once cloud sync is turned on. The person signs in with that phone number to see the account.',
    'Viewers see every entry, total and change, but cannot change anything.',
  ]),
  _Topic(Icons.cloud_sync_outlined, 'Backup', [
    'Backup and restore saves everything to one file you can keep safe or move to another device.',
    'Restoring replaces what is in the app with the backup.',
  ]),
];

/// The built-in guide.
class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('How to use Cash Flow')),
      body: PageBody(
        maxWidth: 760,
        children: [
          Text(
            'Cash Flow is a simple cash book. Everything is saved on this device and works without internet.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final topic in _topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(topic.icon, color: scheme.primary),
                  title: Text(topic.title, style: t.titleMedium),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (var i = 0; i < topic.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: t.labelSmall?.copyWith(color: scheme.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(topic.steps[i], style: t.bodyMedium)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
