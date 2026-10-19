import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../entry/entry_details.dart';
import '../reports/report_data.dart';
import '../widgets/common.dart';

/// Every add, edit and delete, newest first, with old and new values.
/// When accounts are shared this is where people see what others changed.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: AllDataBuilder(
        builder: (context, data) {
          final names = {for (final a in data.accounts) a.id: a.name};
          return FutureBuilder<List<EntryChange>>(
            key: ValueKey('${_all}_${ledger.revision}'),
            future: ledger.repo.activity(accountId: _all ? null : ledger.current?.id),
            builder: (context, snap) {
              final list = snap.data;
              return PageBody(
                children: [
                  ScopePicker(allAccounts: _all, onChanged: (v) => setState(() => _all = v)),
                  const SizedBox(height: 16),
                  if (list == null)
                    const Center(child: CircularProgressIndicator())
                  else if (list.isEmpty)
                    const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      message: 'Adds, edits and deletes will be listed here.',
                    )
                  else
                    SectionCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            ChangeTile(
                              change: list[i],
                              last: i == list.length - 1,
                              title: _all ? names[list[i].accountId] : null,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
