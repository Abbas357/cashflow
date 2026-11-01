import 'dart:io';

import 'package:cash_flow/core/legal/privacy_policy.dart';
import 'package:cash_flow/core/routing/app_router.dart';
import 'package:cash_flow/ui/legal/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tool/make_privacy_html.dart';
import 'routing_test.dart' show pumpApp, settle;

void main() {
  sqfliteFfiInit();
  setUp(() => SharedPreferences.setMockInitialValues({'theme_mode': 'light'}));

  test('the public page matches the text in the app', () {
    final file = File('web/privacy/index.html').readAsStringSync().replaceAll('\r\n', '\n');
    expect(file, privacyHtml(), reason: 'Run: dart run tool/make_privacy_html.dart');
  });

  test('the policy has what Google Play asks for', () {
    final all = [
      privacyIntro,
      for (final s in privacySections) ...[s.title, ?s.intro, ...s.bullets, ?s.outro],
    ].join('\n');
    expect(all, contains(privacyDeveloper));
    expect(all, contains(privacyEmail));
    expect(all, contains('How long data is kept'));
    expect(all, contains(deleteAccountUrl));
    expect(all, isNot(contains('—')));
  });

  testWidgets('opens from its address', (tester) async {
    await pumpApp(tester, Routes.privacyPolicy);
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    expect(find.text('The short version'), findsOneWidget);
  });

  testWidgets('opens from Help', (tester) async {
    await pumpApp(tester, Routes.help);
    await tester.tap(find.text('Privacy policy'));
    await settle(tester);
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
  });

  testWidgets('opens from Settings', (tester) async {
    await pumpApp(tester, Routes.settings);
    final link = find.text('Privacy policy');
    await tester.scrollUntilVisible(link, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await tester.tap(link);
    await settle(tester);
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
  });
}
