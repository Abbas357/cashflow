import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/platform.dart';
import '../../core/utils/responsive.dart';
import '../../state/settings_controller.dart';
import 'app_menu.dart';
import 'menu_search.dart';

/// Wraps every screen. On desktop and web it keeps the sidebar beside the
/// page, so only the content changes when moving between pages. Phones get
/// the page alone (the menu is a drawer); Android and iOS tablets get a
/// fixed menu.
class AppShell extends StatelessWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    if (context.width < Breakpoints.desktop) return child;
    if (!isDesktopLike) {
      return Row(
        children: [
          const SizedBox(width: 288, child: AppMenu(permanent: true)),
          VerticalDivider(width: 1, color: context.cash.hairline),
          Expanded(child: child),
        ],
      );
    }
    return _Sidebared(location: location, child: child);
  }
}

class _Sidebared extends StatefulWidget {
  final String location;
  final Widget child;

  const _Sidebared({required this.location, required this.child});

  @override
  State<_Sidebared> createState() => _SidebaredState();
}

class _SidebaredState extends State<_Sidebared> {
  static const _defaultWidth = 272.0;
  static const _minWidth = 220.0;
  static const _maxWidth = 420.0;
  static const _railWidth = 60.0;
  static const _edgeWidth = 9.0;

  /// Dragging narrower than this folds the sidebar into the rail.
  static const _snapToRail = 170.0;

  late final SettingsController _settings = context.read<SettingsController>();
  late double _width = (_settings.sidebarWidth ?? _defaultWidth).clamp(
    _minWidth,
    _maxWidth,
  );
  late bool _collapsed = _settings.sidebarCollapsed;
  bool _dragging = false;
  bool _hoverEdge = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Ctrl+K searches, Ctrl+B folds the sidebar. Listened to globally so
  /// they work whatever has focus.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!ctrl || !mounted) return false;
    if (e.logicalKey == LogicalKeyboardKey.keyK) {
      // Only when no popup is already open over the page.
      if (ModalRoute.of(context)?.isCurrent ?? true) showMenuSearch(context);
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyB) {
      _toggle();
      return true;
    }
    return false;
  }

  void _save() => _settings.saveSidebar(width: _width, collapsed: _collapsed);

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    _save();
  }

  void _dragStart(DragStartDetails d) {
    setState(() => _dragging = true);
    _follow(d.globalPosition);
  }

  void _dragUpdate(DragUpdateDetails d) => _follow(d.globalPosition);

  /// Puts the edge under the pointer, so it never lags behind or jumps.
  void _follow(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    final x = box.globalToLocal(global).dx - _edgeWidth / 2;
    setState(() {
      if (x < _snapToRail) {
        _collapsed = true;
      } else {
        _collapsed = false;
        _width = x.clamp(_minWidth, _maxWidth);
      }
    });
  }

  void _dragEnd([DragEndDetails? _]) {
    setState(() => _dragging = false);
    _save();
  }

  void _reset() {
    setState(() {
      _width = _defaultWidth;
      _collapsed = false;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.cash;
    final width = _collapsed ? _railWidth : _width;
    final edgeActive = _dragging || _hoverEdge;

    // Painted, so the resize edge never shows the bare window through.
    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          AnimatedContainer(
            // Follow the pointer exactly while dragging; glide otherwise.
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: width,
            child: Material(
              color: scheme.surface,
              child: AppSidebar(
                location: widget.location,
                collapsed: _collapsed,
                onToggle: _toggle,
              ),
            ),
          ),
          // The edge: drag to resize, double-click to reset.
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _hoverEdge = true),
            onExit: (_) => setState(() => _hoverEdge = false),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _dragStart,
              onHorizontalDragUpdate: _dragUpdate,
              onHorizontalDragEnd: _dragEnd,
              onHorizontalDragCancel: _dragEnd,
              onDoubleTap: _reset,
              child: Tooltip(
                message: 'Drag to resize, double-click to reset',
                waitDuration: const Duration(milliseconds: 800),
                child: SizedBox(
                  width: _edgeWidth,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: edgeActive ? 3 : 1,
                      color: edgeActive
                          ? scheme.primary.withValues(alpha: 0.6)
                          : c.hairline,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// The desktop and web sidebar: title with search and fold buttons, the
/// menu, and your profile at the foot. Folded, it is a rail of icons.
class AppSidebar extends StatelessWidget {
  final String location;
  final bool collapsed;
  final VoidCallback onToggle;

  const AppSidebar({
    super.key,
    required this.location,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = context.cash.muted;

    final search = IconButton(
      tooltip: 'Search (Ctrl+K)',
      icon: Icon(Icons.search_rounded, color: muted),
      onPressed: () => showMenuSearch(context),
    );
    final fold = IconButton(
      tooltip: collapsed ? 'Open sidebar (Ctrl+B)' : 'Close sidebar (Ctrl+B)',
      // The icon's panel sits on the right; mirror it so it reads as a
      // left sidebar, like the window it controls.
      icon: Transform.flip(
        flipX: true,
        child: Icon(Icons.view_sidebar_outlined, color: muted),
      ),
      onPressed: onToggle,
    );

    // While the width animates between rail and full, the full layout
    // would overflow; switch layouts only when there is room.
    return LayoutBuilder(
      builder: (context, box) {
        final rail = collapsed || box.maxWidth < 200;
        if (rail) {
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const HomeLink(size: 26),
                fold,
                search,
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: MenuList(location: location, collapsed: true),
                  ),
                ),
                const ProfileFooter(collapsed: true),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                child: Row(
                  children: [
                    Expanded(child: HomeLink(size: 26, style: t.titleMedium)),
                    search,
                    fold,
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: MenuList(location: location),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ProfileFooter(),
              ),
            ],
          ),
        );
      },
    );
  }
}
