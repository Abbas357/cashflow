import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../widgets/common.dart';

class Person {
  final String name;
  final String phone;
  const Person(this.name, this.phone);
}

class PickResult {
  final List<Person> people;
  final AccountRole role;
  const PickResult(this.people, this.role);
}

bool get _hasContactBook =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

/// Lets the owner choose people to share with, and their role. Phones
/// and Macs list the contact book; elsewhere a number is typed in.
Future<PickResult?> pickPeople(BuildContext context) =>
    openAdaptive<PickResult>(context, const _ContactPicker(), height: 680);

class _ContactPicker extends StatefulWidget {
  const _ContactPicker();

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  AccountRole _role = AccountRole.viewer;
  final _picked = <String, Person>{};
  List<Person>? _contacts;
  String? _contactError;
  String _query = '';
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_hasContactBook) _loadContacts();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
        setState(() => _contactError = 'Allow access to contacts to pick people from your phone.');
        return;
      }
      final all = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
      final people = <Person>[];
      for (final c in all) {
        final name = c.displayName ?? '';
        final seen = <String>{};
        for (final p in c.phones) {
          final n = normalizePhone(p.number);
          if (n.length < 8 || !seen.add(n)) continue;
          people.add(Person(name.isEmpty ? n : name, n));
        }
      }
      people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _contacts = people);
    } catch (_) {
      if (mounted) setState(() => _contactError = 'Could not read contacts on this device.');
    }
  }

  void _addTyped() {
    final phone = normalizePhone(_phone.text);
    if (phone.length < 8) {
      toast(context, 'Enter a valid phone number');
      return;
    }
    setState(() {
      _picked[phone] = Person(_name.text.trim().isEmpty ? phone : _name.text.trim(), phone);
      _name.clear();
      _phone.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final contacts = (_contacts ?? const <Person>[])
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.phone.contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Share with')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<AccountRole>(
              segments: const [
                ButtonSegment(
                  value: AccountRole.viewer,
                  icon: Icon(Icons.visibility_outlined),
                  label: Text('View only'),
                ),
                ButtonSegment(
                  value: AccountRole.editor,
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Can edit'),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ),
          if (_picked.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  for (final p in _picked.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(p.name),
                        onDeleted: () => setState(() => _picked.remove(p.phone)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name', isDense: true),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number', isDense: true),
                    onSubmitted: (_) => _addTyped(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add',
                  onPressed: _addTyped,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (_hasContactBook) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search contacts',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: _contactError != null
                  ? EmptyState(
                      icon: Icons.contacts_outlined,
                      title: 'No access to contacts',
                      message: _contactError!,
                      action: OutlinedButton(onPressed: _loadContacts, child: const Text('Try again')),
                    )
                  : _contacts == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (_, i) {
                        final p = contacts[i];
                        final on = _picked.containsKey(p.phone);
                        return CheckboxListTile(
                          value: on,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _picked[p.phone] = p;
                            } else {
                              _picked.remove(p.phone);
                            }
                          }),
                          secondary: CircleAvatar(
                            child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
                          ),
                          title: Text(p.name),
                          subtitle: Text(p.phone),
                        );
                      },
                    ),
            ),
          ] else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This device has no contact book, so type the phone number of '
                  'the person you want to share with. On a phone you can pick '
                  'straight from your contacts.',
                  style: t.bodySmall,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.pop(context, PickResult(_picked.values.toList(), _role)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.brandColor, foregroundColor: Colors.white),
            child: Text(
              _picked.isEmpty
                  ? 'Choose people'
                  : 'Share with ${_picked.length} ${_picked.length == 1 ? 'person' : 'people'}',
            ),
          ),
        ),
      ),
    );
  }
}
