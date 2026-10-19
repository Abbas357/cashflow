import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Who is making changes on this device. A random id until the person
/// signs in to the cloud, when it becomes their Supabase user id.
class Actor {
  final String id;
  final String name;
  const Actor(this.id, this.name);
}

/// Every read and write of accounts and entries goes through here.
///
/// Each write to an entry also records an [EntryChange] with the values
/// before and after, inside the same transaction, so history can never
/// drift from the data.
class LedgerRepository {
  final Database db;
  Actor actor;

  LedgerRepository(this.db, this.actor);

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  static int _firstInt(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? 0 : (rows.first.values.first as num? ?? 0).toInt();

  // ---------------------------------------------------------------- accounts

  Future<List<Account>> accounts() async {
    final rows = await db.query(
      'accounts',
      where: 'deleted_at IS NULL',
      orderBy: 'sort_order, name COLLATE NOCASE',
    );
    return rows.map(Account.fromRow).toList();
  }

  Future<Account> createAccount(String name, {String description = ''}) async {
    final now = DateTime.now();
    final count = _firstInt(await db.rawQuery('SELECT COUNT(*) FROM accounts'));
    final account = Account(
      id: newId(),
      name: name.trim(),
      description: description.trim(),
      ownerId: actor.id,
      sortOrder: count,
      createdAt: now,
      updatedAt: now,
    );
    await db.transaction((txn) async {
      await txn.insert('accounts', account.toRow());
      await txn.insert(
        'account_members',
        AccountMember(
          id: newId(),
          accountId: account.id,
          userId: actor.id,
          displayName: actor.name,
          role: AccountRole.owner,
          joinedAt: now,
        ).toRow(),
      );
    });
    return account;
  }

  Future<void> updateAccount(Account account) async {
    await db.update(
      'accounts',
      {
        'name': account.name.trim(),
        'description': account.description.trim(),
        'sort_order': account.sortOrder,
        'updated_at': isoNow(),
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Soft-deletes the account and its entries, so a sync layer can pass the
  /// deletion on to other devices.
  Future<void> deleteAccount(String id) async {
    final now = isoNow();
    await db.transaction((txn) async {
      await txn.update(
        'accounts',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'entries',
        {'deleted_at': now, 'updated_at': now},
        where: 'account_id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  /// Money in, money out and entry count per account id.
  Future<Map<String, (double, double, int)>> accountTotals() async {
    final rows = await db.rawQuery('''
      SELECT account_id,
             SUM(CASE WHEN type = 'in' THEN amount ELSE 0 END) AS cash_in,
             SUM(CASE WHEN type = 'out' THEN amount ELSE 0 END) AS cash_out,
             COUNT(*) AS n
      FROM entries WHERE deleted_at IS NULL GROUP BY account_id''');
    return {
      for (final r in rows)
        r['account_id'] as String: (
          (r['cash_in'] as num? ?? 0).toDouble(),
          (r['cash_out'] as num? ?? 0).toDouble(),
          r['n'] as int,
        ),
    };
  }

  Future<List<AccountMember>> members(String accountId) async {
    final rows = await db.query(
      'account_members',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'joined_at',
    );
    return rows.map(AccountMember.fromRow).toList();
  }

  /// Shares an account with someone by phone number. Saved as a pending
  /// invite; the sync layer delivers it once cloud sync is on.
  Future<void> invite({
    required String accountId,
    required String name,
    required String phone,
    required AccountRole role,
  }) async {
    final number = normalizePhone(phone);
    await db.transaction((txn) async {
      await txn.insert(
        'account_members',
        AccountMember(
          id: newId(),
          accountId: accountId,
          userId: 'phone:$number',
          displayName: name.trim(),
          phone: number,
          role: role,
          status: MemberStatus.pending,
          joinedAt: DateTime.now(),
        ).toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'accounts',
        {'is_shared': 1, 'updated_at': isoNow()},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
  }

  Future<void> setMemberRole(String memberId, AccountRole role) =>
      db.update('account_members', {'role': role.name}, where: 'id = ?', whereArgs: [memberId]);

  Future<void> removeMember(AccountMember m) async {
    await db.transaction((txn) async {
      await txn.delete('account_members', where: 'id = ?', whereArgs: [m.id]);
      final left = _firstInt(
        await txn.rawQuery(
          "SELECT COUNT(*) FROM account_members WHERE account_id = ? AND role != 'owner'",
          [m.accountId],
        ),
      );
      if (left == 0) {
        await txn.update(
          'accounts',
          {'is_shared': 0, 'updated_at': isoNow()},
          where: 'id = ?',
          whereArgs: [m.accountId],
        );
      }
    });
  }

  // ----------------------------------------------------------------- entries

  /// Live entries, oldest first. Pass [accountId] for one account.
  Future<List<Entry>> entries({String? accountId}) async {
    final rows = await db.query(
      'entries',
      where: accountId == null
          ? 'deleted_at IS NULL'
          : 'deleted_at IS NULL AND account_id = ?',
      whereArgs: accountId == null ? null : [accountId],
      orderBy: 'occurred_at, created_at',
    );
    return rows.map(Entry.fromRow).toList();
  }

  Future<Entry?> entry(String id) async {
    final rows = await db.query('entries', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Entry.fromRow(rows.first);
  }

  Future<Entry> addEntry({
    required String accountId,
    required EntryType type,
    required double amount,
    String note = '',
    required DateTime occurredAt,
    String? attachment,
    String? transferId,
    Transaction? txn,
  }) async {
    final now = DateTime.now();
    final entry = Entry(
      id: newId(),
      accountId: accountId,
      type: type,
      amount: amount,
      note: note.trim(),
      occurredAt: occurredAt,
      attachment: attachment,
      transferId: transferId,
      createdBy: actor.id,
      updatedBy: actor.id,
      createdAt: now,
      updatedAt: now,
    );
    Future<void> write(DatabaseExecutor ex) async {
      await ex.insert('entries', entry.toRow());
      await _log(ex, entry, ChangeAction.created, null, entry.snapshot());
    }

    if (txn != null) {
      await write(txn);
    } else {
      await db.transaction(write);
    }
    return entry;
  }

  /// Saves [changed] over the stored entry and records what moved. When
  /// the entry is half of a transfer, the other half follows its amount
  /// and date.
  Future<void> updateEntry(Entry changed) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'entries',
        where: 'id = ?',
        whereArgs: [changed.id],
      );
      if (rows.isEmpty) return;
      final old = Entry.fromRow(rows.first);
      await _writeUpdate(txn, old, changed);

      if (old.transferId != null) {
        final pair = await txn.query(
          'entries',
          where: 'transfer_id = ? AND id != ? AND deleted_at IS NULL',
          whereArgs: [old.transferId, old.id],
        );
        for (final r in pair) {
          final other = Entry.fromRow(r);
          await _writeUpdate(
            txn,
            other,
            other.copyWith(
              amount: changed.amount,
              occurredAt: changed.occurredAt,
            ),
          );
        }
      }
    });
  }

  Future<void> _writeUpdate(Transaction txn, Entry old, Entry changed) async {
    final before = old.snapshot();
    final after = changed.snapshot();
    final moved = after.keys.any((k) => before[k] != after[k]);
    final attachmentChanged = old.attachment != changed.attachment;
    final accountChanged = old.accountId != changed.accountId;
    if (!moved && !attachmentChanged && !accountChanged) return;

    await txn.update(
      'entries',
      {
        'account_id': changed.accountId,
        'type': changed.type.code,
        'amount': changed.amount,
        'note': changed.note.trim(),
        'occurred_at': toIso(changed.occurredAt),
        'attachment': changed.attachment,
        'updated_by': actor.id,
        'updated_at': isoNow(),
        'version': old.version + 1,
      },
      where: 'id = ?',
      whereArgs: [old.id],
    );
    if (moved) {
      await _log(txn, changed, ChangeAction.updated, before, after);
    }
  }

  /// Soft-deletes an entry and, for a transfer, its other half.
  Future<void> deleteEntry(Entry entry) async {
    await db.transaction((txn) async {
      final targets = entry.transferId == null
          ? [entry]
          : (await txn.query(
              'entries',
              where: 'transfer_id = ? AND deleted_at IS NULL',
              whereArgs: [entry.transferId],
            )).map(Entry.fromRow).toList();
      final now = isoNow();
      for (final e in targets) {
        await txn.update(
          'entries',
          {
            'deleted_at': now,
            'updated_at': now,
            'updated_by': actor.id,
            'version': e.version + 1,
          },
          where: 'id = ?',
          whereArgs: [e.id],
        );
        await _log(txn, e, ChangeAction.deleted, e.snapshot(), null);
      }
    });
  }

  /// Moves [amount] from one account to another as a linked pair.
  Future<void> transfer({
    required Account from,
    required Account to,
    required double amount,
    required DateTime at,
    String note = '',
  }) async {
    final transferId = newId();
    final extra = note.trim().isEmpty ? '' : ': ${note.trim()}';
    await db.transaction((txn) async {
      await addEntry(
        accountId: from.id,
        type: EntryType.cashOut,
        amount: amount,
        note: 'Transfer to ${to.name}$extra',
        occurredAt: at,
        transferId: transferId,
        txn: txn,
      );
      await addEntry(
        accountId: to.id,
        type: EntryType.cashIn,
        amount: amount,
        note: 'Transfer from ${from.name}$extra',
        occurredAt: at,
        transferId: transferId,
        txn: txn,
      );
    });
  }

  // ----------------------------------------------------------------- history

  Future<void> _log(
    DatabaseExecutor ex,
    Entry entry,
    ChangeAction action,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) {
    return ex.insert(
      'entry_changes',
      EntryChange(
        id: newId(),
        accountId: entry.accountId,
        entryId: entry.id,
        action: action,
        before: before,
        after: after,
        changedBy: actor.id,
        changedByName: actor.name,
        changedAt: DateTime.now(),
      ).toRow(),
    );
  }

  Future<List<EntryChange>> historyOf(String entryId) async {
    final rows = await db.query(
      'entry_changes',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(EntryChange.fromRow).toList();
  }

  /// Recent activity across one account, or every account.
  Future<List<EntryChange>> activity({String? accountId, int limit = 300}) async {
    final rows = await db.query(
      'entry_changes',
      where: accountId == null ? null : 'account_id = ?',
      whereArgs: accountId == null ? null : [accountId],
      orderBy: 'changed_at DESC',
      limit: limit,
    );
    return rows.map(EntryChange.fromRow).toList();
  }

  /// Notes used before in an account, most used first, for suggestions.
  Future<List<String>> noteSuggestions(String accountId) async {
    final rows = await db.rawQuery(
      '''SELECT note, COUNT(*) AS n FROM entries
         WHERE account_id = ? AND deleted_at IS NULL AND note != ''
           AND transfer_id IS NULL
         GROUP BY note ORDER BY n DESC, MAX(occurred_at) DESC LIMIT 200''',
      [accountId],
    );
    return rows.map((r) => r['note'] as String).toList();
  }

  // ------------------------------------------------------- backup / restore

  static const _tables = [
    'accounts',
    'account_members',
    'entries',
    'entry_changes',
  ];

  /// Every row of every table, including soft-deleted ones.
  Future<Map<String, List<Map<String, Object?>>>> dump() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in _tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  /// Replaces all local data with [data], as produced by [dump].
  Future<void> restore(Map<String, List<Map<String, Object?>>> data) async {
    await db.transaction((txn) async {
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        final batch = txn.batch();
        for (final row in data[t] ?? const <Map<String, Object?>>[]) {
          batch.insert(t, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> wipe() async {
    await db.transaction((txn) async {
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
    });
  }
}
