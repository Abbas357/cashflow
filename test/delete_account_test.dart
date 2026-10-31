import 'dart:io';

import 'package:cash_flow/core/routing/app_router.dart';
import 'package:cash_flow/core/theme/app_theme.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/models/models.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/services/cloud_sync.dart';
import 'package:cash_flow/state/ledger_controller.dart';
import 'package:cash_flow/state/settings_controller.dart';
import 'package:cash_flow/ui/settings/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed in, with the server's part replaced.
class _Cloud extends CloudSync {
  _Cloud(super.ledger, super.settings);

  bool signed = true;
  Object? refuseWith;
  int deletes = 0;

  @override
  bool get available => true;
  @override
  bool get signedIn => signed;
  @override
  String? get email => 'ali@example.com';
  @override
  String get name => 'Ali';

  @override
  Future<void> deleteFromCloud() async {
    final refusal = refuseWith;
    if (refusal != null) throw refusal;
    deletes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:1',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  late SettingsController settings;
  late LedgerController ledger;
  late _Cloud cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'profile_name': 'Ali', 'profile_address': 'Peshawar'});
    settings = SettingsController(await SharedPreferences.getInstance());
    final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    ledger = LedgerController(LedgerRepository(db, Actor(settings.userId, settings.displayName)), settings);
    await ledger.load();
    cloud = _Cloud(ledger, settings);
  });

  tearDown(() => ledger.repo.db.close());

  Future<void> addBooks() async {
    final a = await ledger.createAccount('Flat');
    await ledger.repo.addEntry(
      accountId: a.id,
      type: EntryType.cashOut,
      amount: 500,
      note: 'Milk',
      occurredAt: DateTime(2026, 10, 15),
    );
    await settings.setEntryDraft('{"note":"half typed"}');
    await settings.setCloudUser('user-1');
  }

  test('deleting removes everything on the device', () async {
    await addBooks();
    final oldId = settings.userId;

    await cloud.deleteAccount();

    expect(cloud.deletes, 1);
    expect(await ledger.repo.db.query('entries'), isEmpty);
    expect(await ledger.repo.db.query('entry_changes'), isEmpty);
    expect(await ledger.repo.db.query('sync_meta'), isEmpty);
    expect(settings.name, isEmpty);
    expect(settings.address, isEmpty);
    expect(settings.entryDraft, isNull);
    expect(settings.cloudUserId, isNull);
    expect(settings.userId, isNot(oldId));
    // Starts again like a fresh install, with nothing of theirs.
    expect(ledger.accounts.map((a) => a.name), ['Personal']);
    expect(ledger.accounts.single.ownerId, settings.userId);
    expect((await ledger.repo.db.query('account_members')).single['user_id'], settings.userId);
  });

  test('when the cloud refuses, nothing on the device changes', () async {
    await addBooks();
    cloud.refuseWith = const SocketException('offline');

    await expectLater(cloud.deleteAccount(), throwsA(isA<SocketException>()));

    expect(ledger.accounts.map((a) => a.name), contains('Flat'));
    expect(await ledger.repo.db.query('entries'), hasLength(1));
    expect(settings.name, 'Ali');
    expect(settings.cloudUserId, 'user-1');
  });

  test('shared accounts are named, unshared and other people\'s are not', () async {
    final mine = await ledger.createAccount('Flat');
    await ledger.createAccount('Private');
    final theirs = await ledger.createAccount('Theirs');
    await ledger.repo.db.update('accounts', {'role': 'editor'}, where: 'id = ?', whereArgs: [theirs.id]);
    for (final (account, status) in [(mine.id, 'active'), (theirs.id, 'active')]) {
      await ledger.repo.db.insert('account_members', {
        'id': 'member-$account',
        'account_id': account,
        'user_id': 'other',
        'display_name': 'Sara',
        'role': 'viewer',
        'status': status,
        'joined_at': isoNow(),
      });
    }

    expect(await ledger.repo.sharedAccountNames(), ['Flat']);
  });

  group('page', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: ledger),
            ChangeNotifierProvider<CloudSync?>.value(value: cloud),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: const DeleteAccountPage()),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }

    Finder button() => find.widgetWithText(FilledButton, 'Delete my account permanently');
    bool enabled(WidgetTester tester) => tester.widget<FilledButton>(button()).onPressed != null;

    testWidgets('the button stays off until DELETE is typed', (tester) async {
      await pump(tester);
      expect(find.textContaining('ali@example.com'), findsOneWidget);
      expect(enabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'delet');
      await tester.pump();
      expect(enabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      expect(enabled(tester), isTrue);
      expect(cloud.deletes, 0);
    });

    testWidgets('a failure says nothing was removed and stays on the page', (tester) async {
      cloud.refuseWith = const SocketException('offline');
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.ensureVisible(button());
      await tester.pump();

      await tester.tap(button());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump();

      expect(find.textContaining('nothing was removed'), findsOneWidget);
      expect(enabled(tester), isTrue);
    });

    testWidgets('signed out, it asks to sign in and offers no way to delete', (tester) async {
      cloud.signed = false;
      await pump(tester);
      expect(find.text('Sign in to delete your account'), findsOneWidget);
      expect(button(), findsNothing);
    });
  });

  test('the public page exists, links to the app page and has no em dash', () {
    final html = File('web/delete-account/index.html').readAsStringSync();
    expect(html, contains('href="..${Routes.deleteAccount}"'));
    expect(html, isNot(contains(String.fromCharCode(0x2014))));
  });
}
