import 'package:flutter/material.dart';

import '../../core/utils/currencies.dart';
import '../../state/settings_controller.dart';

/// Every currency in a dropdown that filters as you type. Focusing it
/// selects the current name, so typing replaces it and searches.
class CurrencyPicker extends StatefulWidget {
  final SettingsController settings;
  final TextEditingController? controller;
  final String? label;
  final String? errorText;
  final VoidCallback? onPicked;

  const CurrencyPicker({
    super.key,
    required this.settings,
    this.controller,
    this.label,
    this.errorText,
    this.onPicked,
  });

  /// The text the field shows once [c] is picked.
  static String labelOf(Currency c) => '${c.name} (${c.code})';

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  final _ownText = TextEditingController();

  TextEditingController get _text => widget.controller ?? _ownText;

  @override
  void dispose() {
    _ownText.dispose();
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
        label: widget.label == null ? null : Text(widget.label!),
        errorText: widget.errorText,
        leadingIcon: SizedBox(
          width: 48,
          child: Center(child: Text(current.symbol, style: const TextStyle(fontWeight: FontWeight.w600))),
        ),
        dropdownMenuEntries: [
          for (final c in currencies)
            DropdownMenuEntry(
              value: c.code,
              label: CurrencyPicker.labelOf(c),
              trailingIcon: Text(c.symbol),
            ),
        ],
        onSelected: (code) {
          if (code != null) {
            widget.settings.setCurrencyCode(code);
            widget.onPicked?.call();
          }
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
