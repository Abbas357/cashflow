import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../navigation/app_menu.dart';
import '../widgets/common.dart';

const _faq = [
  (
    'Where is my data stored?',
    'On this device, in a private database. Nothing is sent anywhere until you turn on cloud sync.',
  ),
  (
    'What does the balance at the bottom mean?',
    'Total Cash In minus Total Cash Out for the period you are looking at. '
        'Each entry also shows the account balance just after it.',
  ),
  (
    'I deleted an entry by mistake.',
    'Open Activity log from the menu to see what it was, then add it again. '
        'Regular backups protect you from bigger mistakes.',
  ),
  (
    'Can two people use the same account?',
    'Yes, once cloud sync is on. Share the account with their mobile number and choose whether they can edit or only view. '
        'They accept the invitation, then see every entry and change.',
  ),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help and about')),
      body: PageBody(
        maxWidth: 680,
        children: [
          Center(
            child: Column(
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: 12),
                Text('Cash Flow', style: t.headlineSmall),
                Text('Version 1.0.0', style: t.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('How to use the app'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.howToUse),
            ),
          ),
          const SizedBox(height: 16),
          Text('Questions', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final q in _faq)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.$1, style: t.titleSmall),
                    const SizedBox(height: 6),
                    Text(q.$2, style: t.bodyMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
