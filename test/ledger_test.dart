import 'package:cash_flow/core/utils/calculator.dart';
import 'package:cash_flow/core/utils/formatters.dart';
import 'package:cash_flow/data/db/app_database.dart';
import 'package:cash_flow/data/models/models.dart';
import 'package:cash_flow/data/repositories/ledger_repository.dart';
import 'package:cash_flow/state/analytics.dart';
import 'package:cash_flow/state/period.dart';
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

  group('repository', () {
    test('creating an account makes the creator its owner', () async {
      final a = await repo.createAccount('Flat Expenditures');
      final members = await repo.members(a.id);
      expect(members.single.role, AccountRole.owner);
      expect(members.single.userId, 'user-1');
    });

    test('editing an entry keeps the previous values in history', () async {
      final a = await repo.createAccount('Home');
      final e = await repo.addEntry(
        accountId: a.id,
        type: EntryType.cashOut,
        amount: 100,
        note: 'Milk',
        occurredAt: DateTime(2026, 10, 15, 19, 30),
      );
      await repo.updateEntry(e.copyWith(amount: 120, note: 'Milk and bread'));

      final saved = await repo.entry(e.id);
      expect(saved!.amount, 120);
      expect(saved.version, 2);

      final history = await repo.historyOf(e.id);
      expect(history.map((h) => h.action), [ChangeAction.updated, ChangeAction.created]);
      final edit = history.first;
      expect(edit.before!['amount'], 100);
      expect(edit.after!['amount'], 120);
      expect(edit.changedFields, containsAll(['amount', 'note']));
      expect(edit.changedByName, 'Ali');
    });

    test('saving an unchanged entry adds no history', () async {
      final a = await repo.createAccount('Home');
      final e = await repo.addEntry(
        accountId: a.id,
        type: EntryType.cashIn,
        amount: 50,
        occurredAt: DateTime(2026, 1, 1),
      );
      await repo.updateEntry(e);
      expect(await repo.historyOf(e.id), hasLength(1));
    });

    test('delete is soft and logged', () async {
      final a = await repo.createAccount('Home');
      final e = await repo.addEntry(
        accountId: a.id,
        type: EntryType.cashIn,
        amount: 10,
        occurredAt: DateTime(2026, 1, 1),
      );
      await repo.deleteEntry(e);
      expect(await repo.entries(accountId: a.id), isEmpty);
      expect((await repo.entry(e.id)), isNotNull);
      expect((await repo.historyOf(e.id)).first.action, ChangeAction.deleted);
    });

    test('transfer writes a linked pair that edits and deletes together', () async {
      final a = await repo.createAccount('Cash');
      final b = await repo.createAccount('Bank');
      await repo.transfer(from: a, to: b, amount: 500, at: DateTime(2026, 10, 1));

      final out = (await repo.entries(accountId: a.id)).single;
      final inn = (await repo.entries(accountId: b.id)).single;
      expect(out.type, EntryType.cashOut);
      expect(inn.type, EntryType.cashIn);
      expect(out.transferId, inn.transferId);

      await repo.updateEntry(out.copyWith(amount: 650));
      expect((await repo.entry(inn.id))!.amount, 650);

      await repo.deleteEntry(inn);
      expect(await repo.entries(), isEmpty);
    });

    test('invites are pending, by normalised phone, and mark the account shared', () async {
      final a = await repo.createAccount('Construction');
      await repo.invite(
        accountId: a.id,
        name: 'Bilal',
        phone: '0300 123-4567',
        role: AccountRole.viewer,
      );
      final members = await repo.members(a.id);
      final invited = members.firstWhere((m) => m.role == AccountRole.viewer);
      expect(invited.phone, '+923001234567');
      expect(invited.isPending, isTrue);
      expect((await repo.accounts()).single.isShared, isTrue);

      await repo.removeMember(invited);
      expect((await repo.accounts()).single.isShared, isFalse);
    });

    test('backup round-trips through dump and restore', () async {
      final a = await repo.createAccount('Home');
      await repo.addEntry(
        accountId: a.id,
        type: EntryType.cashOut,
        amount: 30,
        note: 'Roti',
        occurredAt: DateTime(2026, 10, 15),
      );
      final dump = await repo.dump();
      await repo.wipe();
      expect(await repo.accounts(), isEmpty);
      await repo.restore(dump);
      expect((await repo.entries()).single.note, 'Roti');
      expect(await repo.activity(), hasLength(1));
    });
  });

  group('calculator', () {
    test('respects precedence', () {
      expect(evaluateExpression('1200+350*2-50/5'), 1890);
      expect(evaluateExpression('100×2÷4'), 50);
      expect(evaluateExpression('-5+10'), 5);
      expect(evaluateExpression('120+'), 120);
    });

    test('rejects nonsense and division by zero', () {
      expect(evaluateExpression('abc'), isNull);
      expect(evaluateExpression('5/0'), isNull);
      expect(evaluateExpression(''), isNull);
    });
  });

  group('formatting', () {
    test('lakh and million grouping', () {
      Fmt.currency = '';
      Fmt.decimals = 0;
      Fmt.grouping = NumberGrouping.lakh;
      expect(Fmt.money(478940), '4,78,940');
      expect(Fmt.money(-2972), '-2,972');
      Fmt.grouping = NumberGrouping.million;
      expect(Fmt.money(478940), '478,940');
      Fmt.currency = 'Rs';
      expect(Fmt.money(1250.5), 'Rs 1,250.5');
      Fmt.currency = '';
      Fmt.grouping = NumberGrouping.lakh;
    });

    test('phone numbers normalise to one shape', () {
      expect(normalizePhone('0300-1234567'), '+923001234567');
      expect(normalizePhone('+92 300 1234567'), '+923001234567');
      expect(normalizePhone('0092 300 1234567'), '+923001234567');
    });
  });

  group('periods', () {
    test('weeks start on the chosen day', () {
      final p = Period(kind: PeriodKind.weekly, anchor: DateTime(2026, 10, 19)); // Monday
      expect(p.bounds!.$1, DateTime(2026, 10, 19));
      final sun = Period(
        kind: PeriodKind.weekly,
        anchor: DateTime(2026, 10, 19),
        weekStart: DateTime.sunday,
      );
      expect(sun.bounds!.$1, DateTime(2026, 10, 18));
    });

    test('stepping a month crosses the year', () {
      final p = Period(kind: PeriodKind.monthly, anchor: DateTime(2026, 1, 20)).step(-1);
      expect(p.bounds!.$1, DateTime(2025, 12));
      expect(p.contains(DateTime(2025, 12, 31, 23, 59)), isTrue);
      expect(p.contains(DateTime(2026, 1, 1)), isFalse);
    });
  });

  test('monthly buckets carry the opening balance', () {
    Entry e(DateTime at, double amt, EntryType t) => Entry(
      id: '$at$amt',
      accountId: 'a',
      type: t,
      amount: amt,
      occurredAt: at,
      createdBy: 'u',
      updatedBy: 'u',
      createdAt: at,
      updatedAt: at,
    );
    final list = [
      e(DateTime(2026, 1, 5), 1000, EntryType.cashIn),
      e(DateTime(2026, 9, 5), 300, EntryType.cashOut),
      e(DateTime(2026, 10, 5), 200, EntryType.cashOut),
    ];
    final b = Analytics.lastMonths(list, 2, (d) => '${d.month}', now: DateTime(2026, 10, 19));
    expect(b.map((x) => x.closing), [700, 500]);
    expect(b.last.cashOut, 200);
  });
}
