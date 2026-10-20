# Cash Flow

An offline-first cash book for Android, iOS, Windows, macOS, Linux and the web.
Record money in and money out across separate accounts, see where it goes,
print reports, and sign in with Google to keep the same books on every phone
and browser.

## Running and building

**Live web app:** https://abbas357.github.io/cashflow/ (rebuilt and published
by `.github/workflows/pages.yml` on every push to `main`).


Run these from this folder, in any terminal.

| Command | What it does |
|---|---|
| `dart tool/dev.dart` | Runs the debug build on whichever phone is connected (USB or wireless debugging). Hot reload: `r` reload, `R` restart, `q` quit. |
| `dart tool/dev.dart R5CT51XZF3H` | The same, on a phone you name (the id from `adb devices`). |
| `dart tool/build.dart` | Builds the signed production APK and saves it as `build/app/outputs/flutter-apk/CashFlow-v<version>.apk`, next to `app-release.apk`. |
| `dart tool/build.dart dev` | Builds the dev APK as `build/app/outputs/flutter-apk/CashFlow-Dev-v<version>.apk`, to copy to a phone without a cable. |
| `adb install -r build/app/outputs/flutter-apk/CashFlow-v<version>.apk` | Installs the production APK you already built on the connected phone, no rebuild. `-r` updates it in place and keeps its data. |
| `adb install -r build/app/outputs/flutter-apk/CashFlow-Dev-v<version>.apk` | The same for the dev APK (**Cash Flow Dev**). |
| `flutter run -d chrome` | Runs the web app live in Chrome, with hot reload. |
| `flutter run -d web-server --web-port 8080` | The same, for any browser: open http://localhost:8080. |
| `flutter build web --release --no-web-resources-cdn` then `python tool/serve_web.py` | Builds the release web app and serves it on http://127.0.0.1:8080. See [Open the web app](#open-the-web-app). |
| `python tool/serve_web.py` | Opens the web app you already built (in `build/web`) on http://127.0.0.1:8080, no rebuild. |
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
  stepper and time. Save & continue for quick entry.
* **History on every entry**: each add, edit and delete is kept with the old
  and new values. The Activity log lists them all.
* **Accounts**: switch, search, add, rename, reorder and delete.
* **Transfers** between accounts as a linked pair.
* **Reports**: Insights (monthly in/out chart, balance trend, where the money
  went, spending by weekday, largest expenses), Summary by day, month or
  year, Account summary, Transactions across all accounts, PDF and CSV
  export, printing with your name, address and the app icon in the header.
* **Sharing** (signed in): invite someone by their Gmail address or show a
  QR code, as Can edit or View only. They accept in the app and see every
  entry from then on. The Sharing page shows who accepted and how many
  entries each person made.
* **Notifications**: a bell beside the light/dark switch when someone you
  share with adds, edits or deletes an entry; mark one or all as read.
  Android gets Firebase push notifications even with the app closed (setup
  in [docs/SUPABASE_SYNC.md](docs/SUPABASE_SYNC.md#turning-on-firebase-push)),
  the web app browser notifications.
* **Sign in with Google** (web and Android, no passwords): the books sync to
  Supabase in the background and appear on every device signed in to the
  same Google account. Works offline; changes upload when back online.
* **Backup and restore** to a JSON file.
* **Light and dark** themes (toggle on the main screen). Over 60 currencies
  to pick from, each with its usual number grouping (4,78,940 / 478,940 /
  478.940 / 478 940 / 478'940), which can be changed on its own.
* **Responsive**: phone layout with a drawer and menu search. On desktop and
  web, a sidebar that stays beside every page: drag its edge to resize,
  fold it to icons (`Ctrl+B`), search everything (`Ctrl+K`). Wide screens
  add an overview panel. Shortcuts: `Ctrl+I` Cash In, `Ctrl+O` Cash Out,
  `Ctrl+F` search, `Ctrl+Enter` save.

## Project layout

```
lib/
  core/        theme, formatting, currencies, cloud config, routing
  data/        SQLite schema, models, LedgerRepository
  state/       settings, ledger state, periods, analytics
  services/    cloud sync and Google sign-in, PDF and CSV reports
  ui/          screens (home, entry, accounts, reports, settings, help)
assets/brand/  the app icon and its generated variants
supabase/      cloud schema with RLS, sync stamps, contact matching
docs/          SUPABASE_SYNC.md: how sync works and how to turn it on
tool/          build.dart, dev.dart, make_icons.dart, serve_web.py
test/          unit, routing, sidebar and flow tests, screenshot harness
```

## Web

### Open the web app

**Live, while working on it** (hot reload, debug build):

```
flutter run -d chrome
```

Chrome opens on its own. To use another browser, start a plain server
instead and open the address it prints:

```
flutter run -d web-server --web-port 8080
```

then go to http://localhost:8080. In the terminal, `r` reloads after a code
change, `R` restarts, `q` stops the server.

**The release build, as it will be deployed:**

```
flutter build web --release --no-web-resources-cdn
python tool/serve_web.py
```

then go to http://127.0.0.1:8080. `--no-web-resources-cdn` serves
everything from the app's own host, so it works offline. For another port,
`python tool/serve_web.py 9000`. Press `Ctrl+C` to stop. After changing
code, run the build again and refresh the page (no restart needed).

**A release build you already made:** skip the build and just run

```
python tool/serve_web.py
```

then go to http://127.0.0.1:8080. It serves whatever is in `build/web`
from the last build. Keep the terminal open while you use it. Opening
`build/web/index.html` directly from the folder does not work.

`serve_web.py` listens on this computer only. To open the app from a phone
on the same Wi-Fi, use the live server with
`flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` and go
to `http://<this computer's IP>:8080` (find it with `ipconfig`). Windows may
ask to allow it through the firewall.

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

Sign in with Google and sync through Supabase. It stays off until a
Supabase project is set in `lib/core/config/cloud_config.dart`. See
[docs/SUPABASE_SYNC.md](docs/SUPABASE_SYNC.md) for how it works and the
setup steps (Supabase project, migrations, Google OAuth client, redirect
URLs).
