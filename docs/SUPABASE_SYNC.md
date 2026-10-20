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
(`arkeaalomelhupqrkfec`, Mumbai), all three migrations are applied, and
the app points at it.

1. **Create a Supabase project** at https://supabase.com (free tier is fine).
2. **Run the migrations** in order, in the SQL editor (or `supabase db push`):
   `0001_init.sql`, `0002_google_sync.sql`, `0003_harden_functions.sql`.
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

Sharing still invites people by **mobile number** (`account_members.phone`,
`my_invitations()`), as planned in `0001_init.sql`. Google accounts carry an
email, not a verified number, so invitations will not yet reach the person
they are for. Matching invites by email (or asking for a number once after
sign-in) is the next step.

## Receipts

Receipt photos are still stored on the device only. Uploading them to a
private Storage bucket per account, with the storage path in
`entries.attachment`, is a later step.
