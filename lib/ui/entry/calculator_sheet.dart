import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/calculator.dart';
import '../../core/utils/formatters.dart';

/// A small calculator. Returns the result, or null when dismissed.
Future<double?> showCalculator(BuildContext context, {String initial = ''}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Calculator(initial: initial),
  );
}

class _Calculator extends StatefulWidget {
  final String initial;
  const _Calculator({required this.initial});

  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  late String _expr = widget.initial;

  double? get _value => evaluateExpression(_expr);

  void _press(String k) {
    setState(() {
      switch (k) {
        case 'C':
          _expr = '';
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        case '=':
          final v = _value;
          if (v != null) _expr = _clean(v);
        default:
          final ops = '+−×÷';
          if (ops.contains(k) && (_expr.isEmpty || ops.contains(_expr[_expr.length - 1]))) {
            if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1) + k;
            return;
          }
          _expr += k;
      }
    });
  }

  String _clean(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    const map = {'*': '×', '/': '÷', '-': '−', '+': '+'};
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _press('⌫');
    } else if (e.logicalKey == LogicalKeyboardKey.enter) {
      _done();
    } else if (e.logicalKey == LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    } else if (ch != null && '0123456789.'.contains(ch) && ch.isNotEmpty) {
      _press(ch);
    } else if (ch != null && map.containsKey(ch)) {
      _press(map[ch]!);
    } else if (ch == '=') {
      _press('=');
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _done() {
    final v = _value;
    if (v != null && v >= 0) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final v = _value;
    const keys = [
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '−'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['00', '0', '.', 'OK'],
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expr.isEmpty ? '0' : _expr,
                      style: t.titleMedium?.copyWith(color: context.cash.muted),
                      maxLines: 2,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      v == null ? '' : Fmt.number(v),
                      style: t.displaySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final row in keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (final k in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _Key(
                              label: k,
                              accent: 'C⌫÷×−+='.contains(k),
                              primary: k == 'OK',
                              onTap: () => k == 'OK' ? _done() : _press(k),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final bool accent;
  final bool primary;
  final VoidCallback onTap;

  const _Key({
    required this.label,
    required this.onTap,
    this.accent = false,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = primary
        ? scheme.primary
        : accent
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest;
    final fg = primary ? scheme.onPrimary : (accent ? scheme.primary : scheme.onSurface);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
