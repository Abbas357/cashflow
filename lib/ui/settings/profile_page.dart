import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../widgets/common.dart';

/// Your name, address and phone, printed at the top of reports.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final SettingsController _s = context.read<SettingsController>();
  late final _name = TextEditingController(text: _s.name);
  late final _address = TextEditingController(text: _s.address);
  late final _phone = TextEditingController(text: _s.phone);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _s.setProfile(name: _name.text, address: _address.text, phone: _phone.text);
    if (!mounted) return;
    toast(context, 'Saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your name and address')),
      body: PageBody(
        maxWidth: 560,
        children: [
          Text(
            'Shown on printed reports and PDFs, and to people you share accounts with.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name or business name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
