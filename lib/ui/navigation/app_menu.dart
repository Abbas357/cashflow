import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/cloud_sync.dart';
import 'menu_items.dart';
import 'menu_search.dart';
import 'profile_footer.dart';

export 'profile_footer.dart';

/// The app icon, as shown in the menu, Help and anywhere else the brand
/// appears.
class BrandMark extends StatelessWidget {
  static const asset = 'assets/brand/app_icon.png';

  final double size;
  const BrandMark({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Cash Flow',
  );
}

/// One quiet menu row: icon and label, soft hover, filled when current.
/// In [collapsed] form it is an icon with a tooltip.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.selected = false,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.82);
    final bg = selected ? scheme.onSurface.withValues(alpha: 0.07) : Colors.transparent;
    final hover = scheme.onSurface.withValues(alpha: 0.05);

    final body = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: hover,
        onTap: onTap,
        child: SizedBox(
          height: 38,
          width: collapsed ? 40 : null,
          child: collapsed
              ? Icon(icon, size: 20, color: fg)
              : Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(icon, size: 19, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(badge!, style: t.labelSmall?.copyWith(color: scheme.primary)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: collapsed
          ? Tooltip(message: label, preferBelow: false, waitDuration: const Duration(milliseconds: 300), child: body)
          : body,
    );
  }
}

/// The logo and name at the top of the menu, which go home (the open
/// account's ledger). With no [style], just the logo, for the folded rail.
class HomeLink extends StatelessWidget {
  final TextStyle? style;
  final double size;
  final VoidCallback? onOpen;

  const HomeLink({super.key, this.style, this.size = 30, this.onOpen});

  @override
  Widget build(BuildContext context) {
    void home() {
      onOpen?.call();
      context.go(Routes.home);
    }

    if (style == null) {
      return IconButton(tooltip: 'Home', onPressed: home, icon: BrandMark(size: size));
    }
    return Tooltip(
      message: 'Home',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: home,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              BrandMark(size: size),
              const SizedBox(width: 10),
              Flexible(child: Text('Cash Flow', style: style, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sections and rows. [onOpen] runs before navigating (to close a
/// drawer, for example).
class MenuList extends StatelessWidget {
  final String location;
  final bool collapsed;
  final VoidCallback? onOpen;

  const MenuList({super.key, required this.location, this.collapsed = false, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cloud = context.watch<CloudSync?>();
    final signedIn = cloud?.signedIn ?? false;
    final waiting = cloud?.invitations.length ?? 0;
    final sections = [
      for (final s in menuSections)
        MenuSection(s.title, [for (final i in s.items) if (signedIn || !i.signedInOnly) i]),
    ].where((s) => s.items.isNotEmpty);

    return Column(
      crossAxisAlignment: collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (section.title != null)
            collapsed
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(width: 24, child: Divider(height: 1, color: context.cash.hairline)),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
                    child: Text(section.title!, style: t.labelMedium),
                  )
          else if (i > 0)
            const SizedBox(height: 12),
          for (final item in section.items)
            MenuRow(
              icon: item.icon,
              label: item.label,
              // Invitations waiting for you show on Sharing.
              badge: item.path == Routes.sharing && waiting > 0 ? '$waiting' : item.badge,
              collapsed: collapsed,
              selected: item.isCurrent(location),
              onTap: () {
                onOpen?.call();
                context.go(item.path);
              },
            ),
        ],
      ],
    );
  }
}

/// The menu on phones (a drawer) and on Android or iOS tablets (fixed at
/// the side). Desktop and web use [AppSidebar] instead.
class AppMenu extends StatelessWidget {
  final bool permanent;

  const AppMenu({super.key, this.permanent = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;
    void close() {
      if (!permanent) Navigator.of(context).pop();
    }

    final body = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(child: HomeLink(style: t.titleLarge, onOpen: close)),
                IconButton(
                  tooltip: 'Search menu',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => showMenuSearch(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: MenuList(location: location, onOpen: close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ProfileFooter(onOpen: close),
          ),
        ],
      ),
    );

    if (permanent) return Material(color: scheme.surface, child: body);
    return Drawer(width: 304, child: body);
  }
}
