import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';

/// The local SQLite store.
///
/// The tables mirror the Supabase schema in `supabase/migrations`, column
/// for column: text UUID ids, UTC ISO timestamps, soft deletes and a
/// version number. That keeps the door open for an offline-first sync layer
/// (PowerSync, which speaks SQLite on the device and Postgres on Supabase)
/// without reshaping data later.
class AppDatabase {
  static const fileName = 'cash_flow.db';
  static const version = 1;

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
        onCreate: (db, _) => _create(db),
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
}
