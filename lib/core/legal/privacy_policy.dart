/// The privacy policy: one text for the app's page and the public web page.
///
/// After changing it, run `dart run tool/make_privacy_html.dart` to rewrite
/// web/privacy/index.html. A test fails if the two differ.
library;

class PolicySection {
  final String title;
  final String? intro;
  final List<String> bullets;
  final String? outro;

  const PolicySection(this.title, {this.intro, this.bullets = const [], this.outro});
}

const privacyUpdated = '1 November 2026';
const privacyDeveloper = 'Abbas Khan';
const privacyEmail = 'abbaskhan357@gmail.com';
const privacyUrl = 'https://abbas357.github.io/cashflow/privacy/';
const deleteAccountUrl = 'https://abbas357.github.io/cashflow/delete-account/';

const privacyIntro =
    'Cash Flow is a cash book for Android and the web, made by $privacyDeveloper. This policy explains '
    'what the app collects, why, who can see it, how long it is kept and how you can delete it.';

const privacySections = <PolicySection>[
  PolicySection(
    'The short version',
    bullets: [
      'Until you sign in, your accounts and entries stay on your device.',
      'To count users per country, the app sends a small usage record with no name or entries in it. You can delete it in Settings.',
      'If you sign in with Google, your accounts and entries are also stored in the cloud, so they stay safe and reach your other devices and the people you share with.',
      'Cash Flow has no ads, and your data is not sold.',
    ],
  ),
  PolicySection(
    'What stays on your device',
    intro: 'These are kept in the app on your device:',
    bullets: [
      'Your accounts, entries, notes and change history, until you sign in.',
      'Receipt photos you attach. They are not uploaded, even when you are signed in.',
      'Your address and phone number, which are printed on the reports you create.',
      'Your name, which is also printed on reports. If you sign in, it is stored with the changes you make, as described below.',
      'Your settings, such as currency and theme.',
    ],
    outro: 'Backup, PDF and CSV files are saved or shared only where you choose.',
  ),
  PolicySection(
    'Usage statistics',
    intro:
        'To count how many people use Cash Flow in each country, the app sends the following to our cloud '
        'provider, Supabase, whether or not you have signed in:',
    bullets: [
      'A random ID created for this installation. It is not linked to your Google account.',
      'Your country, worked out on your device from your SIM, mobile network, time zone or language setting. The app does not use GPS and asks for no permission to do this.',
      'Your currency.',
      'Your device type, for example Android or web.',
    ],
    outro:
        'Your name, address, email, phone number, accounts and entries are never part of this. As with any '
        'internet connection, Supabase can see your IP address when the app connects; it is not stored with '
        'these statistics. You can see this information and delete it in Settings, under Usage statistics, '
        'which also stops the app sending it from that device.',
  ),
  PolicySection(
    'If you sign in with Google',
    intro: 'Signing in is optional. If you do, the following is stored in the cloud so your books stay in step on every device:',
    bullets: [
      'From Google: your name, email address, profile photo and account ID. Cash Flow never sees your Google password.',
      'Your accounts, entries, amounts, dates, notes and change history, including the name shown with each change.',
    ],
  ),
  PolicySection(
    'Sharing an account',
    intro: 'Sharing happens only when you choose it:',
    bullets: [
      'People you share an account with can see its entries and history, and the name shown with each change.',
      'When you invite someone by email, their address is stored so the invitation can reach them. An invitation can also be a QR code that you show them.',
      'Your name and email can be shown to the other members of a shared account.',
    ],
  ),
  PolicySection(
    'Notifications',
    bullets: [
      'On Android, after you sign in, your phone registers a notification token with Google\'s Firebase Cloud Messaging. It is stored with your account and removed when you sign out or turn these notifications off in Settings.',
      'When someone changes a shared account, the other members are notified with who made the change, the type of entry, the amount and the note. On Android this message passes through Firebase.',
      'On the web, your browser shows these notifications itself while the page is open.',
    ],
  ),
  PolicySection(
    'Permissions on Android',
    bullets: [
      'Internet: for sign-in, sync and usage statistics.',
      'Notifications: to tell you about changes in shared accounts.',
      'Camera: only when you choose to scan an invitation QR code or photograph a receipt.',
    ],
    outro:
        'Photos you attach are chosen by you with the phone\'s own picker. Cash Flow does not read your '
        'contacts, messages or precise location.',
  ),
  PolicySection(
    'Who provides these services',
    bullets: [
      'Supabase stores the cloud data and runs sign-in. Its servers for Cash Flow are in Mumbai, India, so your data may be handled outside your country.',
      'Google provides Google sign-in, and Firebase Cloud Messaging on Android.',
      'GitHub Pages hosts the web app and, like any web host, can see your IP address when you open it.',
    ],
    outro:
        'Your data is not sold or used for advertising, and it is not given to anyone else unless the law '
        'requires it.',
  ),
  PolicySection(
    'How your data is protected',
    intro:
        'Data travels over encrypted HTTPS connections. In the cloud, access rules let only you and the people '
        'you share an account with read it. Data on your device relies on your device\'s own security, such as '
        'its screen lock. No system is completely secure, so keep your device and Google account protected.',
  ),
  PolicySection(
    'How long data is kept, and deleting it',
    bullets: [
      'On your device: until you use Settings, Delete all data, or remove the app. Signing out removes the copy on that device.',
      'In the cloud: until you delete your account, so your books are there when you sign in again. An entry you delete is kept marked as deleted so the deletion can reach your other devices, and it is removed for good when your account is deleted.',
      'Deleting your account: use Settings, Delete account in the app, or visit $deleteAccountUrl. It happens at once and cannot be undone. Entries you added to accounts other people own stay in their books, shown as made by "Deleted user". Technical logs at Supabase may mention your account until they expire shortly afterwards.',
      'Usage statistics: kept until you delete them in Settings, and removed when you delete your account. Removing the app does not remove them, so delete them in Settings first if you want them gone.',
    ],
  ),
  PolicySection(
    'Your choices',
    intro:
        'You can use Cash Flow without signing in, and sign out at any time. You can correct your details in the '
        'app, and email us to ask what we hold about you or to have it corrected or deleted.',
  ),
  PolicySection(
    'Children',
    intro:
        'Cash Flow is not directed at children under 13, and we do not knowingly collect their information. If '
        'you believe a child has used it, email us and we will delete what we hold.',
  ),
  PolicySection(
    'Changes to this policy',
    intro:
        'If this policy changes, the new version will appear in the app and at $privacyUrl with a new date at the top.',
  ),
  PolicySection(
    'Contact',
    intro: 'For questions or requests about your privacy, contact $privacyDeveloper at $privacyEmail.',
  ),
];
