import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/privacy_policy.dart';
import '../widgets/common.dart';

/// The privacy policy inside the app, readable offline. The public copy for
/// Google Play is web/privacy/index.html, made from the same text.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: PageBody(
        maxWidth: 680,
        children: [
          Text('Last updated $privacyUpdated', style: t.bodySmall),
          const SizedBox(height: 8),
          SelectableText(privacyIntro, style: t.bodyMedium),
          for (final s in privacySections) ...[
            const SizedBox(height: 10),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.title, style: t.titleSmall),
                  if (s.intro != null) ...[
                    const SizedBox(height: 6),
                    SelectableText(s.intro!, style: t.bodyMedium),
                  ],
                  for (final item in s.bullets)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•', style: t.bodyMedium),
                          const SizedBox(width: 8),
                          Expanded(child: SelectableText(item, style: t.bodyMedium)),
                        ],
                      ),
                    ),
                  if (s.outro != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(s.outro!, style: t.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'mailto', path: privacyEmails.join(','))),
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Email about privacy'),
          ),
        ],
      ),
    );
  }
}
