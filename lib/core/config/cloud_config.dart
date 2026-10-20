import 'package:flutter/foundation.dart';

import 'page_base_io.dart' if (dart.library.js_interop) 'page_base_web.dart';

/// Where the cloud copy lives. Sign-in and sync stay hidden until both are
/// set, so the app works fully offline without them.
///
/// The "cashflow" Supabase project (Mumbai). To point at another, change
/// the two defaults below, or pass them at build time:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
/// The publishable (anon) key is meant to ship in apps: row level security
/// in `supabase/migrations` decides what each person can see.
class CloudConfig {
  CloudConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://arkeaalomelhupqrkfec.supabase.co');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_ExaJ_yylXdIZzhkJCFaODA_u5W7mqjo',
  );

  static bool get enabled => url != '' && publishableKey != '';

  /// Google sign-in returns to the app by a redirect: the page itself on
  /// the web, a deep link on Android and iOS. Desktop apps have neither.
  static bool get signInSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The deep link scheme, one per app id so the dev and production apps
  /// each get their own sign-in back (android/app/build.gradle.kts).
  static const _scheme = kDebugMode ? 'com.finance.cashflow.dev' : 'com.finance.cashflow';

  /// Where Google sends people back to. Each must be listed in Supabase
  /// under Authentication, URL Configuration, Redirect URLs.
  /// On the web that is the app's own folder (`/` locally, `/cashflow/`
  /// on GitHub Pages), not whatever page it was on.
  /// The published web app. Invitation links and QR codes point here, so
  /// they open on any phone, with or without the app.
  static const webAppUrl = 'https://abbas357.github.io/cashflow/';

  static String get redirectUrl => kIsWeb ? pageBase() : '$_scheme://login-callback';
}
