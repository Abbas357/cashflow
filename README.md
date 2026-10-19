# Cash Flow

An offline-first cash book for Android, iOS, Windows, macOS, Linux and the web.
Record money in and money out across separate accounts, see where it goes,
print reports, and (once cloud sync is switched on) share accounts with people
from your contacts.

## Running and building

Run these from this folder, in any terminal.

| Command | What it does |
|---|---|
| `dart tool/dev.dart` | Runs the debug build on whichever phone is connected (USB or wireless debugging). Hot reload: `r` reload, `R` restart, `q` quit. |
| `dart tool/dev.dart R5CT51XZF3H` | The same, on a phone you name (the id from `adb devices`). |
| `dart tool/build.dart` | Builds the signed production APK and saves it as `build/app/outputs/flutter-apk/CashFlow-v<version>.apk`, next to `app-release.apk`. |
| `dart tool/build.dart dev` | Builds the dev APK as `build/app/outputs/flutter-apk/CashFlow-Dev-v<version>.apk`, to copy to a phone without a cable. |
| `flutter run -d chrome` | Runs the web app in Chrome. |
| `flutter test` | Runs the tests. |

- The dev build installs as **Cash Flow Dev** (`com.finance.cash_flow.dev`)
  and the production build as **Cash Flow** (`com.finance.cash_flow`). Both
  can sit on the phone together, each with its own data, so trying a change
  never touches your real books.
- To install, copy the APK to the phone and open it (allow installs from
  that app when asked), or with a cable:
  `adb install -r build/app/outputs/flutter-apk/CashFlow-v<version>.apk`.
- Before a release, raise `version:` in `pubspec.yaml` (for example
  `1.0.0+1` to `1.0.1+2`). The number after the `+` must go up, or phones
  will not take the APK as an update.
- Signing uses `android/key.properties` and `android/cashflow-release.jks`.
  Both are git-ignored, so **keep a backup**: without them, an update cannot
  be signed and phones will refuse to install it over the existing app.
- Builds need no internet. The Android toolchain (Gradle 8.14, Android Gradle
  Plugin 8.11.1, Kotlin 2.2.20) matches the HRM app, so it comes from the
  same Gradle cache (`GRADLE_USER_HOME`, here `E:\dev\gradle`). Plugins that
  pin other Android Gradle Plugin versions are built with these too
  (`android/build.gradle.kts`).
- On Windows, Android and Windows builds need Developer Mode on
  (`start ms-settings:developers`) so Flutter can link plugins. Windows
  desktop builds also need Visual Studio with "Desktop development with C++".

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
  export, printing with your name, address and the app icon in the header.
* **Sharing**: share an account with contacts as Can edit or View only. The
  person accepts the invitation by mobile number. Invites are saved locally
  until cloud sync is enabled.
* **Backup and restore** to a JSON file.
* **Light and dark** themes (toggle on the main screen), lakh or million
  number grouping, any currency symbol.
* **Responsive**: phone layout with a drawer and menu search. On desktop and
  web, a sidebar that stays beside every page: drag its edge to resize,
  fold it to icons (`Ctrl+B`), search everything (`Ctrl+K`). Wide screens
  add an overview panel. Shortcuts: `Ctrl+I` Cash In, `Ctrl+O` Cash Out,
  `Ctrl+F` search, `Ctrl+Enter` save.

## Project layout

```
lib/
  core/        theme, formatting, calculator, breakpoints, routing
  data/        SQLite schema, models, LedgerRepository
  state/       settings, ledger state, periods, analytics
  services/    PDF and CSV reports
  ui/          screens (home, entry, accounts, reports, settings, help)
assets/brand/  the app icon and its generated variants
supabase/      cloud schema with RLS, history trigger, contact matching
docs/          SUPABASE_SYNC.md: the sync and sharing plan
tool/          build.dart, dev.dart, make_icons.dart, serve_web.py
test/          unit, routing, sidebar and flow tests, screenshot harness
```

## Web

Build with `flutter build web --release --no-web-resources-cdn` (everything
served from the app's own host, so it works offline), then preview with
`python tool/serve_web.py` on http://127.0.0.1:8080.

**Addresses.** Every page has a real address (`/insights`, `/reports`,
`/settings`, ...). The ledger lives at `/account/<uuid>`, with the Cash In
and Cash Out popups at `/account/<uuid>/cash-in` and `/account/<uuid>/cash-out`.
How the account is being viewed rides in the query, for example
`/account/<uuid>?period=monthly&date=2026-10-01&q=milk`, so a refresh, Back
or a bookmark lands on the same screen. `/` opens the current account. A
half-typed Cash In or Cash Out survives a refresh.

Because the addresses are real paths, the web host must send unknown paths
to `index.html`:

* Local preview: `python tool/serve_web.py` does this
* Firebase Hosting: `"rewrites": [{"source": "**", "destination": "/index.html"}]`
* Nginx: `try_files $uri $uri/ /index.html;`
* Netlify: a `_redirects` file with `/* /index.html 200`

**Loading screen.** While the app starts, `web/index.html` shows the icon
with a progress bar. `web/flutter_bootstrap.js` moves the bar at each
startup stage (code downloaded, engine started, app running) and it fades
out on the first frame.

**Storage.** The web build keeps its data in SQLite compiled to WebAssembly
(`web/sqlite3.wasm`, `web/sqflite_sw.js`). If the `sqflite_common_ffi_web`
package is upgraded, refresh them with
`dart run sqflite_common_ffi_web:setup --force`.

## App icon

The source is `assets/brand/app_icon.png`. To change it, replace that file
and run:

```
dart run tool/make_icons.dart
dart run flutter_launcher_icons
dart run tool/make_icons.dart
```

The first run makes the platform variants (Android adaptive foreground, iOS
square, macOS margin, web maskable, and the Android launch picture: the
small icon with an empty progress bar, matching the app's startup screen); `flutter_launcher_icons` places them on
every platform; the second run restores the web favicon and maskable icons
that it overwrites.

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
