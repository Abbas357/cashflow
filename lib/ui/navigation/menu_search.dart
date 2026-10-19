import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../state/ledger_controller.dart';
import '../../state/settings_controller.dart';
import 'menu_items.dart';

class _Result {
  final IconData icon;
  final String title;
  final String kind;
  final void Function(BuildContext context) run;
  const _Result(this.icon, this.title, this.kind, this.run);
}

/// Finds anything in the menu, any account, or a quick action, by typing.
/// A centred box on desktop and web, full screen on phones.
Future<void> showMenuSearch(BuildContext context) {
  // Opened from the drawer: close it first so the result lands on the page.
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  if (context.isPhone) {
    return showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => const Dialog.fullscreen(child: _MenuSearch()),
    );
  }
  return showDialog(
    context: context,
    barrierColor: Colors.black38,
    builder: (_) => Align(
      alignment: const Alignment(0, -0.55),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: const Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          elevation: 8,
          child: _MenuSearch(),
        ),
      ),
    ),
  );
}

class _MenuSearch extends StatefulWidget {
  const _MenuSearch();

  @override
  State<_MenuSearch> createState() => _MenuSearchState();
}

class _MenuSearchState extends State<_MenuSearch> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<_Result> _results() {
    final ledger = context.read<LedgerController>();
    final settings = context.read<SettingsController>();
    final dark = settings.isDark(context);

    void go(BuildContext ctx, String path) => GoRouter.of(ctx).go(path);

    final all = <_Result>[
      for (final item in allMenuItems)
        _Result(item.icon, item.label, 'Page', (ctx) => go(ctx, item.path)),
      if (ledger.canEdit) ...[
        for (final type in EntryType.values)
          _Result(
            type.isIn ? Icons.add_rounded : Icons.remove_rounded,
            type.label,
            'Action',
            (ctx) => go(ctx, Routes.withQuery(Routes.newEntry(type, ledger.current!.id), ledger.viewQuery)),
          ),
      ],
      _Result(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        dark ? 'Switch to light mode' : 'Switch to dark mode',
        'Action',
        (ctx) => settings.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
      ),
      for (final a in ledger.accounts)
        _Result(Icons.folder_open_rounded, a.name, 'Account', (ctx) async {
          await ledger.selectAccount(a);
          if (ctx.mounted) go(ctx, Routes.home);
        }),
    ];

    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    final keywords = {for (final i in allMenuItems) i.label: i.keywords};
    bool hit(_Result r) =>
        r.title.toLowerCase().contains(q) ||
        (keywords[r.title] ?? '').contains(q) ||
        r.kind.toLowerCase() == q;
    // Titles that start with the query rank first.
    final found = all.where(hit).toList()
      ..sort((a, b) {
        final sa = a.title.toLowerCase().startsWith(q) ? 0 : 1;
        final sb = b.title.toLowerCase().startsWith(q) ? 0 : 1;
        return sa - sb;
      });
    return found;
  }

  void _run(_Result r) {
    // The search box is a route on the root navigator; capture the page
    // context beneath it before closing.
    final nav = Navigator.of(context);
    final target = nav.context;
    nav.pop();
    r.run(target);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e, List<_Result> results) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, results.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, results.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.enter && results.isNotEmpty) {
      _run(results[_selected]);
    } else {
      return KeyEventResult.ignored;
    }
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (_selected * 48.0 - 120).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = context.cash;
    final results = _results();
    if (_selected >= results.length) _selected = results.isEmpty ? 0 : results.length - 1;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Focus(
              onKeyEvent: (n, e) => _onKey(n, e, results),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() => _selected = 0),
                decoration: InputDecoration(
                  hintText: 'Search pages, accounts and actions',
                  prefixIcon: context.isPhone
                      ? IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        )
                      : const Icon(Icons.search_rounded),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: c.hairline),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Nothing matches.', style: t.bodyMedium?.copyWith(color: c.muted)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(6),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final r = results[i];
                      final on = i == _selected;
                      return Material(
                        color: on ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _run(r),
                          onHover: (h) => h ? setState(() => _selected = i) : null,
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(r.icon, size: 20, color: on ? scheme.primary : c.muted),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(r.title, style: t.bodyMedium, overflow: TextOverflow.ellipsis),
                                ),
                                Text(r.kind, style: t.labelSmall),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!context.isPhone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
              child: Text(
                'Up and down to choose, Enter to open, Esc to close',
                style: t.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
