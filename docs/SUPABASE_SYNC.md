# Cloud sync and Google sign-in

Cash Flow is **offline-first**. Every read and write goes to the SQLite
database on the device. Signing in with Google adds a copy in Supabase that
stays in step in the background, so the same books appear on every phone
and browser the person signs in on.

```
 Phone / Desktop / Web                            Supabase
 +--------------------------------+              +------------------------------+
 | UI  ->  LedgerRepository       |              | Auth: Google                 |
 |            |  SQL              |   upsert     | Postgres                     |
 |            v                   | -----------> |  accounts, entries,          |
 |   local SQLite (always)        |              |  account_members,            |
 |     triggers -> sync_outbox    |   select     |  entry_changes               |
 |            ^                   | <----------- |  RLS: owner/editor/viewer    |
 |            |  CloudSync        |   realtime   |  updated_at stamped on write |
 +--------------------------------+ <- - - - - - +------------------------------+
```

## Signing in

* **Web:** "Continue with Google" at the bottom left of the sidebar sends the
  tab to Google's account chooser and back, like Claude's own sign-in.
  Supabase finishes the sign-in on load (`Supabase.initialize` in
  `lib/boot.dart`) and clears `?code=` from the address.
* **Android:** the same button at the bottom of the drawer opens Google in
  the browser; it returns to the app by the deep link
  `com.finance.cashflow://login-callback` (`com.finance.cashflow.dev://...`
  for the dev app), declared in `AndroidManifest.xml`.
* **Desktop apps** have no redirect to come back to, so they stay offline
  and say so. Use the web app on a computer.
* There are no passwords. Supabase keeps the session on the device and
  refreshes it.

## How sync works (`lib/services/cloud_sync.dart`)

1. **Outbox.** Triggers on the four tables (`lib/data/db/app_database.dart`,
   schema version 2) record every insert, update and delete in
   `sync_outbox`, one row per changed record. Changes made offline, or
   before signing in, wait there.
2. **First sign-in on a device.** Rows written so far carry a random local
   id as their author; it becomes the Google user's id. If the cloud already
   has books and this device only has the empty starter "Personal" account,
   that account is dropped instead of uploaded, so it does not appear twice.
3. **Upload.** Waiting rows go up with `upsert`, parents first (accounts,
   members, entries, history). A row the cloud refuses for good (for
   example an edit to an account shared as view only) is counted and
   skipped so it cannot block the rest; network errors leave everything
   queued for the next try.
4. **Download.** For each table, rows whose server `updated_at` is newer
   than the last download come down a page at a time, ordered by
   `(updated_at, id)`. A row with a newer change still waiting on the
   device is left alone; that change wins and comes back after uploading.
   Members are few and come down in full, so removals show too.
5. **When.** After each change on the device (1.2 s later), on sign-in, when
   the app comes back to the front, every two minutes, and at once when
   Supabase Realtime reports a change from another device.
6. **Sign out** uploads what it can, then removes the device's copy. The
   books come back on the next sign-in.

History (`entry_changes`) is written by the device at the moment of each
change, offline or not, and uploaded like everything else. The server
trigger from `0001_init.sql` is dropped in `0002_google_sync.sql`: it would
have stamped the time of upload and logged each change twice.

Two people editing the same entry offline: the last upload wins, and both
edits stay in the entry's history with their before and after values.

## Turning it on

Steps 1, 2 and 6 are done: the project is **cashflow**
(`arkeaalomelhupqrkfec`, Mumbai), all five migrations and the notify-changes function are in place, and
the app points at it.

1. **Create a Supabase project** at https://supabase.com (free tier is fine).
2. **Run the migrations** in order, in the SQL editor (or `supabase db push`):
   `0001_init.sql`, `0002_google_sync.sql`, `0003_harden_functions.sql`,
   `0004_share_by_email_and_qr.sql`, `0005_push_devices.sql`. Deploy
   `supabase/functions/notify-changes` (with JWT verification off: it
   checks the caller itself).
3. **Google OAuth client.** In Google Cloud Console, APIs and Services,
   Credentials: create an OAuth client ID of type **Web application**.
   Authorised redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback`.
4. **Enable Google in Supabase.** Authentication, Sign In / Providers,
   Google: paste the client ID and secret.
5. **Redirect URLs.** Authentication, URL Configuration, Redirect URLs, add:
   * `http://localhost:*/**` and `http://127.0.0.1:*/**` (local web, any port)
   * `https://abbas357.github.io/cashflow/**` (GitHub Pages)
   * `com.finance.cashflow://login-callback`
   * `com.finance.cashflow.dev://login-callback`

   Set Site URL to `https://abbas357.github.io/cashflow/`.
6. **Point the app at it.** Paste the Project URL and the publishable (anon)
   key from Project Settings, API into `lib/core/config/cloud_config.dart`,
   or pass them when building:
   `--dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_KEY=<key>`.

Until step 6, the app runs exactly as before, fully offline; the Google
button explains that sign-in is not set up in that build.

## Sharing

People sign in with Google, so they are found by the address Google
verified (`0004_share_by_email_and_qr.sql`). In an account's **Share**
screen the owner picks **Can edit** or **View only**, then either:

* **Invites by email.** The Gmail address is saved as a pending
  `account_members` row (offline too; it uploads with everything else).
  When that person opens the app, `my_invitations()` finds it and the home
  screen shows it with **Accept** and **Decline**. Declined invitations
  show as Declined to the owner, who can invite again.
* **Shows a QR code.** `account_invites` holds a code for one account and
  role, valid for a day or until the owner stops it. It encodes
  `https://abbas357.github.io/cashflow/join/<code>`: the Android app scans
  it under **Sharing, Scan QR code**; any phone camera opens it in the web
  app. `invite_code_details()` says what it is for, and `join_with_code()`
  joins on **Accept**. Scanned while signed out, the code is kept and
  offered again right after Google sign-in.

After joining, the next sync notices an account it can see but does not
have, and downloads it whole (account, entries, history). People removed
from an account lose it from their devices on the next sync.

The menu's **Sharing** page (signed in only) lists invitations waiting for
you, accounts shared with you, and everyone you shared with: whether they
accepted, their role, and how many entries they made.

## Notifications

The **bell** next to the light/dark switch counts changes other people
made (added, edited or deleted an entry) as unread until opened or **Mark
all read**.

**Android: Firebase push, as in the HRM app.** After uploading entry
history to a shared account, the app calls the `notify-changes` Edge
Function (`supabase/functions/notify-changes`) with the ids. It pushes
"Abbas added Cash Out 500: Milk" through Firebase Cloud Messaging to every
other active member's phones (`push_devices`, migration
`0005_push_devices.sql`). Android shows it even when Cash Flow is closed;
tapping it opens the account. Each phone registers its Firebase token after
Google sign-in and removes it on sign-out or when notifications are turned
off in Settings.

**Web:** the browser shows a notification when a sync brings someone
else's change, while the page is open.

### Turning on Firebase push

1. **Firebase project.** At https://console.firebase.google.com, add a
   project (for example "Cash Flow"; Google Analytics is not needed).
2. **Android apps.** In the project, Add app, Android, twice:
   `com.finance.cash_flow` (Cash Flow) and `com.finance.cash_flow.dev`
   (Cash Flow Dev). After the second one, download `google-services.json`
   (it covers both) into `android/app/`. Builds apply the Google services
   plugin only when that file is there. It is git-ignored (the repo is
   public), so keep a copy with the signing key.
3. **Service account key.** Project settings, Service accounts, Generate new
   private key. Keep the downloaded JSON private.
4. **Give it to the Edge Function.** Supabase dashboard, Edge Functions,
   Secrets: add `FIREBASE_SERVICE_ACCOUNT` with the whole JSON file as the
   value. Then delete the downloaded file.
5. **Rebuild the APK** (`dart tool/build.dart`) and install it on both
   phones.

## Web updates

GitHub Pages lets browsers keep files for 10 minutes. After each build,
`tool/web_cache_bust.dart` gives the scripts versioned addresses
(`main.dart.js?v=<commit>`, `canvaskit-<engine>/`), so a plain refresh
loads the new version. The running app also checks `build_id.txt` every few
minutes and when the tab comes back to the front, and offers **Reload**
when a newer build is live.

## Receipts

Receipt photos are still stored on the device only. Uploading them to a
private Storage bucket per account, with the storage path in
`entries.attachment`, is a later step.
