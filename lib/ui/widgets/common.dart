import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';

/// An amount in the in / out colour, with an optional sign.
class AmountText extends StatelessWidget {
  final double value;
  final bool isIn;
  final TextStyle? style;
  final bool signed;

  const AmountText(
    this.value, {
    super.key,
    required this.isIn,
    this.style,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    final sign = signed ? (isIn ? '+' : '-') : '';
    return Text(
      '$sign${Fmt.money(value.abs())}',
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: isIn ? c.inText : c.outText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A balance: green when positive, red when negative.
class BalanceText extends StatelessWidget {
  final double value;
  final TextStyle? style;

  const BalanceText(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    return Text(
      Fmt.money(value),
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: value < 0 ? c.outText : c.inText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The round in / out marker beside an entry.
class EntryTypeIcon extends StatelessWidget {
  final bool isIn;
  final bool transfer;
  final double size;

  const EntryTypeIcon({
    super.key,
    required this.isIn,
    this.transfer = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cash;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isIn ? c.inSoft : c.outSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        transfer
            ? Icons.swap_horiz_rounded
            : (isIn ? Icons.south_west_rounded : Icons.north_east_rounded),
        size: size * 0.5,
        color: isIn ? c.inText : c.outText,
      ),
    );
  }
}

/// A titled card section for settings, reports and details.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// A label over a number, used in total strips and summary tiles.
class StatTile extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? iconColor;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? context.cash.muted),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label, style: t.labelMedium, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value,
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Scrolls when space is short (a phone on its side, or with the
    // keyboard up) instead of overflowing.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: t.bodyMedium?.copyWith(color: context.cash.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Asks a yes / no question. Returns true on yes.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(88, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for one line of text, such as an account name.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Name',
  String action = 'Save',
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: submit,
            child: Text(action),
          ),
        ],
      );
    },
  );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Opens [page] full screen on a phone, or as a centred dialog on wider
/// screens so a form does not stretch across a monitor.
Future<T?> openAdaptive<T>(
  BuildContext context,
  Widget page, {
  double width = 560,
  double height = 720,
}) {
  if (context.isPhone) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: width,
          height: height.clamp(0, size.height - 48),
          child: page,
        ),
      );
    },
  );
}

/// A standard page body: scrolls, and stays a readable width on desktop.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const PageBody({super.key, required this.children, this.maxWidth = 820});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.isPhone ? 16 : 24,
        vertical: 16,
      ),
      children: [
        MaxWidth(
          maxWidth: maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
