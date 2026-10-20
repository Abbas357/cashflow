import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/models/models.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late LedgerRepository repo;

  setUp(() async {
    final db = await AppDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    repo = LedgerRepository(db, const Actor('user-1', 'Ali'));
  });

  tearDown(() => repo.db.close());

  Future<List<(String, String)>> outbox() async => [
    for (final r in await repo.db.query('sync_outbox', orderBy: 'seq'))
      (r['tbl'] as String, r['op'] as String),
  ];

  test('every local write waits in the outbox for upload', () async {
    final a = await repo.createAccount('Home');
    final e = await repo.addEntry(
      accountId: a.id,
      type: EntryType.cashOut,
      amount: 100,
      note: 'Milk',
      occurredAt: DateTime(2026, 10, 15),
    );
    await repo.updateEntry(e.copyWith(amount: 120));

    final queued = await outbox();
    expect(queued.where((q) => q.$1 == 'accounts'), hasLength(1));
    expect(queued.where((q) => q.$1 == 'account_members'), hasLength(1));
    // Added then edited: still one upload of the latest row.
    expect(queued.where((q) => q.$1 == 'entries'), hasLength(1));
    expect(queued.where((q) => q.$1 == 'entry_changes'), hasLength(2));
    expect(queued.every((q) => q.$2 == 'upsert'), isTrue);
  });

  test('removing a person queues a delete', () async {
    final a = await repo.createAccount('Flat');
    await repo.invite(accountId: a.id, name: 'Sara', phone: '03001234567', role: AccountRole.viewer);
    await repo.db.delete('sync_outbox');

    final invited = (await repo.members(a.id)).firstWhere((m) => m.role == AccountRole.viewer);
    await repo.removeMember(invited);

    expect(await outbox(), contains(('account_members', 'delete')));
  });

  test('rows written while applying downloads are not sent back', () async {
    await repo.db.transaction((txn) async {
      await txn.insert('sync_meta', {'key': 'applying', 'value': '1'});
      await txn.insert('accounts', {
        'id': 'from-cloud',
        'name': 'Shop',
        'owner_id': 'user-2',
        'created_at': isoNow(),
        'updated_at': isoNow(),
      });
      await txn.delete('sync_meta', where: 'key = ?', whereArgs: ['applying']);
    });

    expect(await outbox(), isEmpty);
    expect((await repo.accounts()).single.name, 'Shop');
  });
}
