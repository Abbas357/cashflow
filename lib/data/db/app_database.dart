import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';

/// The local SQLite store.
///
/// The tables mirror the Supabase schema in `supabase/migrations`, column
/// for column: text UUID ids, UTC ISO timestamps, soft deletes and a
/// version number. That keeps the door open for an offline-first sync layer
/// (PowerSync, which speaks SQLite on the device and Postgres on Supabase)
/// without reshaping data later.
///
/// Version 2 adds the sync outbox: triggers note every insert, update and
/// delete in [syncedTables], so changes made offline (or before signing
/// in) upload once there is a connection. Rows arriving from the cloud are
/// written while `sync_meta` holds an `applying` row, which the triggers
/// skip, so downloads are not sent straight back up.
class AppDatabase {
  static const fileName = 'cash_flow.db';
  static const version = 2;

  /// The tables copied to the cloud, parents first.
  static const syncedTables = ['accounts', 'account_members', 'entries', 'entry_changes'];

  static Future<Database> open() async {
    final (factory, path) = await openFactory(fileName);
    return openWith(factory, path);
  }

  static Future<Database> openWith(DatabaseFactory factory, String path) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _create(db);
          await _createSync(db);
        },
        onUpgrade: (db, from, _) async {
          if (from < 2) {
            await _createSync(db);
            // Everything written before the outbox existed still has to
            // reach the cloud on the first sign-in.
            for (final t in syncedTables) {
              await db.execute(
                "INSERT OR REPLACE INTO sync_outbox (tbl, row_id, op) SELECT '$t', id, 'upsert' FROM $t",
              );
            }
          }
        },
      ),
    );
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        owner_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'owner',
        is_shared INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )''');
    batch.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        type TEXT NOT NULL CHECK (type IN ('in', 'out')),
        amount REAL NOT NULL CHECK (amount >= 0),
        note TEXT NOT NULL DEFAULT '',
        occurred_at TEXT NOT NULL,
        attachment TEXT,
        transfer_id TEXT,
        created_by TEXT NOT NULL,
        updated_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1
      )''');
    batch.execute(
      'CREATE INDEX idx_entries_account ON entries(account_id, occurred_at)',
    );
    batch.execute('CREATE INDEX idx_entries_transfer ON entries(transfer_id)');
    batch.execute('''
      CREATE TABLE entry_changes (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        action TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        changed_by TEXT NOT NULL,
        changed_by_name TEXT NOT NULL DEFAULT '',
        changed_at TEXT NOT NULL
      )''');
    batch.execute(
      'CREATE INDEX idx_changes_entry ON entry_changes(entry_id, changed_at)',
    );
    batch.execute(
      'CREATE INDEX idx_changes_account ON entry_changes(account_id, changed_at)',
    );
    batch.execute('''
      CREATE TABLE account_members (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        display_name TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        joined_at TEXT NOT NULL,
        UNIQUE (account_id, user_id)
      )''');
    await batch.commit(noResult: true);
  }

  static Future<void> _createSync(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE sync_outbox (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        tbl TEXT NOT NULL,
        row_id TEXT NOT NULL,
        op TEXT NOT NULL,
        UNIQUE (tbl, row_id)
      )''');
    batch.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    const local = "NOT EXISTS (SELECT 1 FROM sync_meta WHERE key = 'applying')";
    for (final t in syncedTables) {
      for (final (event, row, op) in [
        ('INSERT', 'NEW', 'upsert'),
        ('UPDATE', 'NEW', 'upsert'),
        ('DELETE', 'OLD', 'delete'),
      ]) {
        batch.execute('''
          CREATE TRIGGER sync_${t}_${event.toLowerCase()} AFTER $event ON $t
          WHEN $local
          BEGIN
            INSERT OR REPLACE INTO sync_outbox (tbl, row_id, op) VALUES ('$t', $row.id, '$op');
          END''');
      }
    }
    await batch.commit(noResult: true);
  }
}
