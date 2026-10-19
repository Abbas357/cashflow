import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_controller.dart';
import 'menu_items.dart';
import 'menu_search.dart';

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
    return Column(
      crossAxisAlignment: collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in menuSections.indexed) ...[
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
              badge: item.badge,
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

/// Your name at the foot of the menu; opens Settings.
class ProfileFooter extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onOpen;

  const ProfileFooter({super.key, this.collapsed = false, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final t = Theme.of(context).textTheme;
    final name = s.name.isEmpty ? 'You' : s.name;
    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: AppTheme.brandColor,
      foregroundColor: Colors.white,
      child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
    void open() {
      onOpen?.call();
      context.go(Routes.settings);
    }

    if (collapsed) {
      return Tooltip(
        message: '$name: Settings',
        child: IconButton(onPressed: open, icon: avatar),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text('Offline, saved on this device', style: t.labelSmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const BrandMark(),
                const SizedBox(width: 10),
                Expanded(child: Text('Cash Flow', style: t.titleLarge)),
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
