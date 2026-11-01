import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/cloud_config.dart';
import '../../services/cloud_sync.dart';
import '../../state/settings_controller.dart';
import '../legal/privacy_policy_page.dart';
import '../navigation/app_menu.dart';
import '../widgets/currency_picker.dart';
import '../widgets/google_button.dart';

/// The popup someone new sees the first time the app opens: their name,
/// address and currency, and what signing in with Google would add. It can
/// only be left through its buttons, so a name and currency are always set.
Future<void> showWelcome(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeDialog(),
  );
}

class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  static const _benefits = [
    'Keep your data after reinstalling the app or changing your phone',
    'See the same data on all your devices',
    'Share an account and work on it with friends and family',
    'Get a notification when someone adds, changes or removes an entry in a shared account',
  ];

  late final SettingsController _settings = context.read<SettingsController>();
  late final CloudSync? _cloud = context.read<CloudSync?>();
  late final _name = TextEditingController(text: _settings.name);
  late final _address = TextEditingController(text: _settings.address);
  final _currency = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _currencyError;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _cloud?.addListener(_onCloud);
  }

  @override
  void dispose() {
    _cloud?.removeListener(_onCloud);
    _name.dispose();
    _address.dispose();
    _currency.dispose();
    super.dispose();
  }

  bool get _canSignIn => (_cloud?.available ?? false) && CloudConfig.signInSupported;

  bool _validate() {
    final named = _form.currentState!.validate();
    // Typing in the field searches, so it can be left cleared or half typed.
    final picked = _currency.text.trim() == CurrencyPicker.labelOf(_settings.currencyInfo);
    setState(() => _currencyError = picked ? null : 'Choose a currency');
    return named && picked;
  }

  Future<void> _save() async {
    await _settings.setProfile(name: _name.text, address: _address.text, phone: _settings.phone);
    await _settings.keepCurrency();
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    await _settings.setOnboarded();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _continueOffline() async {
    if (!_validate()) return;
    await _save();
    await _close();
  }

  /// Google's window must open straight from the tap, so the details are
  /// saved alongside it rather than waited for.
  void _continueWithGoogle() {
    if (!_validate()) return;
    unawaited(_save());
    signInWithGoogle(context, _cloud!);
  }

  void _onCloud() {
    if (_cloud?.signedIn ?? false) unawaited(_close());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandMark(size: 44)),
                        const SizedBox(height: 10),
                        Text('Welcome to Cash Flow', style: t.titleLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          // Clears "Enter your name" as soon as one is typed.
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: 'Name or business name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          minLines: 1,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Address (optional)',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CurrencyPicker(
                          settings: settings,
                          controller: _currency,
                          label: 'Currency',
                          errorText: _currencyError,
                          onPicked: () => setState(() => _currencyError = null),
                        ),
                        const SizedBox(height: 16),
                        _OfflineNote(benefits: _canSignIn ? _benefits : const []),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canSignIn) ...[
                      GoogleButton(onPressed: _continueWithGoogle),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      onPressed: _continueOffline,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: _canSignIn
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Continue offline', textAlign: TextAlign.center),
                                Text(
                                  'Google can be connected later via side menu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                                ),
                              ],
                            )
                          : const Text('Continue'),
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

/// Says the app works offline, then what signing in would add, if it can.
class _OfflineNote extends StatelessWidget {
  final List<String> benefits;

  const _OfflineNote({required this.benefits});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cash Flow works offline. Your entries are saved only on this device.',
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
          if (benefits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Sign in with Google to:', style: t.titleSmall),
            for (final b in benefits)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded, size: 16, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: t.bodySmall)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            'To count users per country, Cash Flow sends a random ID, your country, '
            'currency and device type. Never your name or entries. You can delete it in Settings.',
            style: t.bodySmall,
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: t.labelMedium,
            ),
            // Above this popup, which stays open underneath.
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
            ),
            child: const Text('Privacy policy'),
          ),
        ],
      ),
    );
  }
}
