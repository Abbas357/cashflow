# Cash Flow

An offline-first cash book for Android, iOS, Windows, macOS, Linux and the web.
Record money in and money out across separate accounts, see where it goes,
print reports, and (once cloud sync is switched on) share accounts with people
from your contacts.

## Features

* **Ledger**: entries grouped by day, newest first, with running balance.
  Filter by All, Daily, Weekly, Monthly, Yearly or any date range. Search
  notes and amounts. Sort by date or notes.
* **Big Cash In / Cash Out buttons** with totals for the period on screen.
* **Entry form**: amount with built-in calculator (type `250+120` or use the
  keypad), note suggestions from earlier entries, receipt photo, date
  stepper and time. Save and continue for quick entry.
* **History on every entry**: each add, edit and delete is kept with the old
  and new values. The Activity log lists them all.
* **Accounts**: switch, search, add, rename, reorder and delete.
* **Transfers** between accounts as a linked pair.
* **Reports**: Insights (monthly in/out chart, balance trend, where the money
  went, spending by weekday, largest expenses), Summary by day, month or
  year, Account summary, Transactions across all accounts, PDF and CSV
  export, printing with your name and address in the header.
* **Sharing**: share an account with contacts as Can edit or View only.
  Invites are saved locally until cloud sync is enabled.
* **Backup and restore** to a JSON file.
* **Light and dark** themes (toggle on the main screen), lakh or million
  number grouping, any currency symbol.
* **Responsive**: phone layout with a drawer; desktop layout with a fixed
  menu and, on wide screens, an overview panel. Keyboard shortcuts on
  desktop: `Ctrl+I` Cash In, `Ctrl+O` Cash Out, `Ctrl+F` search,
  `Ctrl+Enter` save.

## Project layout

```
lib/
  core/        theme, formatting, calculator, breakpoints
  data/        SQLite schema, models, LedgerRepository
  state/       settings, ledger state, periods, analytics
  services/    PDF and CSV reports
  ui/          screens (home, entry, accounts, reports, settings, help)
supabase/      cloud schema with RLS, history trigger, contact matching
docs/          SUPABASE_SYNC.md: the sync and sharing plan
test/          unit tests and a screenshot harness
```

## Running

```
flutter pub get
flutter run                 # pick a device
flutter run -d chrome       # web
flutter run -d windows      # needs Visual Studio "Desktop development with C++"
flutter test
```

On Windows, building for Android or Windows needs Developer Mode turned on
(`start ms-settings:developers`) so Flutter can link plugins.

The web build stores data with SQLite compiled to WebAssembly
(`web/sqlite3.wasm`, `web/sqflite_sw.js`). If the `sqflite_common_ffi_web`
package is upgraded, refresh them with:

```
dart run sqflite_common_ffi_web:setup --force
```

## Screenshots for review

```
flutter test test/screenshots_test.dart --dart-define=SHOTS=build/shots
```

renders the main screen (phone and desktop, light and dark) and Insights to PNG.

## Cloud sync

The app is built so that sync can be added without reshaping data. See
[docs/SUPABASE_SYNC.md](docs/SUPABASE_SYNC.md) for the plan: Supabase for
Postgres, phone sign-in and row-level security, and PowerSync as the
offline sync connector.
