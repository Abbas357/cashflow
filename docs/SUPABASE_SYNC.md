# Cloud sync and sharing plan

Cash Flow is **offline-first**. Every read and write goes to the SQLite
database on the device. The cloud has one job: copy changes in the
background, so people who share an account see each other's entries and
edits, including the value an edit replaced.

```
 Phone / Desktop / Web                       Supabase
 +---------------------------+              +-----------------------------+
 | UI  ->  LedgerRepository  |              | Postgres                    |
 |            |  SQL         |   upload     |  accounts, entries,         |
 |            v              | -----------> |  account_members,           |
 |   local SQLite (always)   |              |  entry_changes (trigger)    |
 |            ^              | <----------- |  RLS: owner/editor/viewer   |
 |            | PowerSync    |   stream     | Auth: phone number + OTP    |
 +---------------------------+              +-----------------------------+
```

## Why PowerSync as the connector

* The app already speaks SQL to SQLite. PowerSync keeps a SQLite database on
  the device and syncs it with Supabase Postgres, so `LedgerRepository`
  keeps its queries. Only the code that opens the database changes.
* Writes are queued while offline and uploaded when the network returns.
* Supabase publishes an official PowerSync integration and a Flutter
  `SupabaseConnector` template.
* A local Supabase (the CLI with Docker) is still useful for development.
  It is not what users connect to.

## What is already in place

| Ready now | Where |
|---|---|
| UUID text ids, UTC ISO timestamps, soft deletes, `version` | `lib/data/db/app_database.dart` |
| One class for every read and write | `lib/data/repositories/ledger_repository.dart` |
| Change history with before/after values | `entry_changes` table, `EntryChange` model |
| Roles: owner, editor, viewer | `AccountRole`, enforced in the UI |
| Share with contacts, invites saved as pending | `SharingPage`, `contact_picker.dart`, `account_members` |
| Phone number normalisation (`+923001234567`) | `normalizePhone()` in `models.dart` |
| Cloud schema, RLS, history trigger, contact matching | `supabase/migrations/0001_init.sql` |

## Sharing through contacts

**Identity.** The mobile number is how a person is identified and found
when sharing. Each number belongs to one user (`profiles.phone` is
unique) and an account can hold one invite per number. Every table still
uses a UUID primary key: numbers change hands and get recycled, and a
UUID keeps a person's history intact when that happens.

1. Each person signs in once with their mobile number (Supabase phone OTP).
   A trigger copies the verified number into `profiles.phone` and stores
   `sha256(phone)` in `profiles.phone_hash`.
2. In **Share account**, the owner picks people from the phone's contacts
   (or types a number on desktop) and chooses **Can edit** or **View only**.
3. To show which contacts already use the app, the device sends **hashes**
   of its contacts' numbers to `match_contacts()`. Raw numbers never leave
   the phone.
4. Each share is an `account_members` row with that number, the role, and
   status `pending`. Nothing about the account is visible to the invitee
   yet.
5. The invited person signs in with that number and sees the invitation
   (`my_invitations()`: account name, who shared it, the role). They
   **accept** (`accept_invitation`) or **decline** (`decline_invitation`).
6. On accept, the row becomes `active` with their user id. From then on
   the account, its entries and the full change history sync to their
   devices, and every later change arrives in the background.
7. RLS lets active members read an account, its entries and its history.
   Only owners and editors can write entries. Only the owner invites,
   changes roles or removes people.

## History of changes

The server trigger `log_entry_change()` writes `entry_changes` for every
insert, update and soft delete, with `old_data` and `new_data` as JSON.
Members download it like any other table, and the app already renders it
("Milk: Rs 100 -> Rs 120, edited by Ali").

On the device the repository also logs changes, so history works offline.
With sync on, mark `entry_changes` as **download-only** in the PowerSync
schema and skip it in `uploadData`, so the server trigger is the single
source. Local rows are replaced by the server's copies when they arrive.

## Turning it on: steps

1. **Supabase project.** Create it, enable Phone auth (an SMS provider such
   as Twilio), then run `supabase/migrations/0001_init.sql`
   (`supabase db push`).
2. **PowerSync.** Create an instance connected to the Supabase database.
   Sync rules, in short:
   ```yaml
   bucket_definitions:
     my_accounts:
       parameters: >
         select account_id, role from account_members
         where user_id = request.user_id() and status = 'active'
       data:
         - select * from accounts where id = bucket.account_id
         - select * from entries where account_id = bucket.account_id
         - select * from entry_changes where account_id = bucket.account_id
         - select * from account_members where account_id = bucket.account_id
   ```
   The device's `accounts.role` column is filled from the member row (or a
   view) so the UI keeps reading `account.role`.
3. **Flutter.** Add `supabase_flutter` and `powersync`. Add a sign-in screen
   (phone and OTP). Replace `AppDatabase.open()` with a `PowerSyncDatabase`
   using the same table definitions, and add the `SupabaseConnector` from
   the PowerSync template (`fetchCredentials` + `uploadData`).
4. **First sync.** Data created offline before sign-in already has UUIDs.
   Set `owner_id`, `created_by` and `updated_by` from the local id to the
   signed-in user id once, then let it upload.
5. **Receipts.** Upload attachments to a private Storage bucket per
   account, and store the storage path in `entries.attachment`.
6. **Contacts.** Hash each normalised contact number with sha256, call
   `match_contacts`, and mark matching contacts in the picker. Pending
   invites already saved on the device upload with everything else.
7. **Invitations screen.** List `my_invitations()` after sign-in (and
   when a push notification arrives), with Accept and Decline.

## Conflicts

Two people may edit the same entry offline. PowerSync uploads in order and
the last write wins on the server. Nothing is lost, because the trigger
records both edits with their before and after values, and both show in
the entry's history. If stricter rules are needed later, compare the
`version` column in `uploadData` and ask the user to choose.
