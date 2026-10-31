import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/cloud_config.dart';
import '../core/utils/formatters.dart';
import '../data/db/app_database.dart';
import '../data/models/models.dart';
import '../state/ledger_controller.dart';
import '../state/settings_controller.dart';
import 'auth_popup_io.dart' if (dart.library.js_interop) 'auth_popup_web.dart';
import 'notifier.dart';
import 'push.dart';

enum SyncState {
  /// No cloud project in this build.
  unavailable,
  signedOut,
  syncing,
  synced,

  /// The last attempt could not reach the cloud. Changes wait on the device.
  offline,

  /// The cloud answered with an error. Tried again on the next change.
  failed,
}

/// Signs in with Google and keeps the device's books and the cloud copy in
/// step, in the background.
///
/// The device stays the source of truth for the screens: every read and
/// write still goes to local SQLite. Triggers there queue each change in
/// `sync_outbox` (see [AppDatabase]); this class uploads the queue, then
/// downloads whatever changed in the cloud since the last time, by the
/// server's `updated_at`. It runs after local changes, when the app comes
/// back to the front, on a timer, and when the cloud reports a change.
class CloudSync extends ChangeNotifier with WidgetsBindingObserver {
  final LedgerController ledger;
  final SettingsController settings;

  CloudSync(this.ledger, this.settings);

  static const _pageSize = 500;

  /// How long the app waits after the last change on this device before
  /// uploading, so a run of entries goes up together.
  static const _uploadDelay = Duration(seconds: 10);

  /// How often it checks the cloud when Realtime has said nothing.
  static const _checkEvery = Duration(minutes: 5);
  static const _nilId = '00000000-0000-0000-0000-000000000000';

  /// Postgres errors that mean the cloud will never take this row (no
  /// permission, broken reference, bad value). The row is skipped so it
  /// cannot hold back everything queued after it.
  static const _rejectCodes = {'42501', '23503', '23505', '23514', '23502', '22P02', '22003'};

  SyncState status = SyncState.unavailable;
  DateTime? lastSynced;

  /// Google's sign-in window is open. The buttons show a spinner meanwhile.
  bool signingIn = false;

  /// Changes on this device that have not reached the cloud yet.
  int pending = 0;

  /// Changes the cloud refused (for example to an account shared as view
  /// only), and the last error, for the details sheet.
  int rejected = 0;
  String? error;

  /// Invitations to other people's accounts, waiting for an answer.
  List<Invitation> invitations = const [];

  /// Changes other people made, brought by the last download, still to
  /// be announced.
  final _news = <Map<String, dynamic>>[];

  /// Firebase pushes for this phone (Android), once signed in.
  late final Push _pushes = Push(_client);

  void Function(String accountId)? _onOpenAccount;
  String? _openPending;

  /// Opens the account a tapped push is about. Set by the app once it is
  /// up; a push that opened the app before that waits for it.
  set onOpenAccount(void Function(String accountId)? open) {
    _onOpenAccount = open;
    final waiting = _openPending;
    if (open != null && waiting != null) {
      _openPending = null;
      open(waiting);
    }
  }

  void _openFromPush(String accountId) {
    final open = _onOpenAccount;
    if (open == null) {
      _openPending = accountId;
    } else {
      open(accountId);
    }
  }

  StreamSubscription<AuthState>? _auth;
  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _periodic;
  String? _uid;
  int _seenRevision = 0;
  AuthPopup? _popup;
  Timer? _signInBackedOut;
  bool _running = false;
  bool _deleting = false;
  bool _showingArrivals = false;
  bool _again = false;

  Database get _db => ledger.repo.db;
  SupabaseClient get _client => Supabase.instance.client;

  bool get available => CloudConfig.enabled;
  User? get user => available ? _client.auth.currentUser : null;
  bool get signedIn => user != null;

  String get name {
    final meta = user?.userMetadata ?? const {};
    final n = (meta['full_name'] ?? meta['name'] ?? '') as String;
    return n.trim().isNotEmpty ? n.trim() : (user?.email ?? 'You');
  }

  String? get email => user?.email;
  String? get avatarUrl {
    final meta = user?.userMetadata ?? const {};
    return (meta['avatar_url'] ?? meta['picture']) as String?;
  }

  /// Starts listening for sign-in and changes. Call once, after the ledger
  /// has loaded.
  Future<void> start() async {
    if (!available) return;
    status = SyncState.signedOut;
    _seenRevision = ledger.revision;
    ledger.addListener(_onLedger);
    WidgetsBinding.instance.addObserver(this);
    await _countPending();
    _auth = _client.auth.onAuthStateChange.listen(
      (s) => unawaited(_onAuth(s.session?.user)),
      onError: (Object e) {
        error = '$e';
        notifyListeners();
      },
    );
    try {
      await _onAuth(_client.auth.currentUser);
    } catch (e) {
      status = SyncState.failed;
      error = '$e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _signInBackedOut?.cancel();
    _debounce?.cancel();
    _periodic?.cancel();
    _channel?.unsubscribe();
    ledger.removeListener(_onLedger);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------- sign in

  /// Opens Google's account chooser: a small window over the page on the
  /// web, a Custom Tab (Chrome's minimal window, inside the app) on Android.
  /// The session arrives through [_onAuth]; [signingIn] is on until then, or
  /// until the person backs out.
  ///
  /// The window must open straight from the tap, so nothing here waits first.
  Future<void> signIn() async {
    if (signingIn) {
      _popup?.focus();
      return;
    }
    _setSigningIn(true);
    try {
      if (kIsWeb) {
        await _signInOnWeb();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await _signInOnAndroid();
      } else {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: CloudConfig.redirectUrl,
          queryParams: _signInQuery,
        );
      }
    } catch (_) {
      _setSigningIn(false);
      rethrow;
    }
  }

  static const _signInQuery = {'prompt': 'select_account'};

  Future<void> _signInOnWeb() async {
    final popup = AuthPopup.open();
    // Blocked: the whole tab goes to Google and comes back instead.
    if (popup == null) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: CloudConfig.redirectUrl,
        queryParams: _signInQuery,
      );
      return;
    }
    _popup = popup;
    try {
      final OAuthResponse start;
      try {
        start = await _client.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: '${CloudConfig.redirectUrl}${AuthPopup.callbackPage}',
          queryParams: _signInQuery,
        );
      } catch (_) {
        popup.close();
        rethrow;
      }
      popup.go(start.url);
      final result = await popup.result;
      final code = result.code;
      if (code != null) {
        await _client.auth.exchangeCodeForSession(code);
      } else if (result.error != null && result.error != 'access_denied') {
        throw AuthException(result.error!);
      }
    } finally {
      _popup = null;
      _setSigningIn(false);
    }
  }

  /// Not `signInWithOAuth`: it always sends Google sign-in on Android out to
  /// the browser app. A Custom Tab is a real browser, so Google accepts it,
  /// and the deep link back closes it (`singleTask` in AndroidManifest.xml).
  Future<void> _signInOnAndroid() async {
    final start = await _client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: CloudConfig.redirectUrl,
      queryParams: _signInQuery,
    );
    final tab = await supportsLaunchMode(LaunchMode.inAppBrowserView);
    await launchUrl(
      Uri.parse(start.url),
      mode: tab ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
    );
  }

  void _setSigningIn(bool on) {
    _signInBackedOut?.cancel();
    if (signingIn == on) return;
    signingIn = on;
    notifyListeners();
  }

  /// Uploads what it can, signs out, and removes this device's copy of the
  /// books. They stay in the cloud for the next sign-in.
  Future<void> signOut() async {
    try {
      await sync();
    } catch (_) {}
    await _leave(settings.forgetCloudUser);
  }

  /// Deletes this person for good: their account and books in the cloud,
  /// their Google details held there (see `0006_delete_account.sql`), then
  /// everything on this device. Throws with nothing changed if the cloud
  /// cannot be reached or refuses.
  Future<void> deleteAccount() async {
    // No sync may run alongside: one finishing after the wipe below would
    // write downloaded rows back to the device.
    _deleting = true;
    _debounce?.cancel();
    try {
      while (_running) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await deleteFromCloud();
    } catch (_) {
      _deleting = false;
      rethrow;
    }
    _news.clear();
    rejected = 0;
    error = null;
    await _leave(settings.eraseAll);
    _deleting = false;
  }

  /// The part of [deleteAccount] that needs the server.
  @protected
  Future<void> deleteFromCloud() => _client.rpc<void>('delete_my_account');

  /// Ends the session and removes this device's copy of the books, then
  /// [forget]s who was signed in.
  Future<void> _leave(Future<void> Function() forget) async {
    // While still signed in, so the server forgets this phone.
    await _pushes.stop();
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    await _onAuth(null);
    invitations = const [];
    await settings.setUnreadChanges({});
    await _wipeLocal();
    await forget();
    await ledger.reload();
    _seenRevision = ledger.revision;
    await _countPending();
    notifyListeners();
  }

  Future<void> _onAuth(User? u) async {
    if (u != null) _setSigningIn(false);
    if (u?.id == _uid) return;
    _uid = u?.id;
    if (u == null) {
      unawaited(_pushes.stop());
      _periodic?.cancel();
      await _channel?.unsubscribe();
      _channel = null;
      status = SyncState.signedOut;
      notifyListeners();
      return;
    }
    await _adopt(u);
    _listenForChanges();
    _periodic?.cancel();
    _periodic = Timer.periodic(_checkEvery, (_) => _schedule(Duration.zero));
    await sync();
    await updatePush();
  }

  /// Registers this phone for pushes when signed in with notifications on
  /// (Settings), and stops them otherwise.
  Future<void> updatePush() async {
    if (!Push.available) return;
    if (signedIn && settings.notifyChanges) {
      await _pushes.start(
        // Android shows nothing for a push while the app is open.
        onArrived: (title, body) {
          unawaited(Notifier.show(title, body));
          _schedule(Duration.zero);
        },
        onOpened: _openFromPush,
      );
    } else {
      await _pushes.stop();
    }
  }

  /// Ties the device's books to [u] the first time they sign in here.
  ///
  /// Everything written so far was authored by a random local id; it
  /// becomes the user's id, so the cloud accepts it as theirs. Books left
  /// by someone else who never signed out are removed first, so one
  /// person's entries never upload into another's account.
  Future<void> _adopt(User u) async {
    final tied = settings.cloudUserId;
    if (tied == u.id) return;
    if (tied != null) await _wipeLocal();

    final old = settings.userId;
    await _db.transaction((txn) async {
      await txn.rawUpdate('UPDATE accounts SET owner_id = ? WHERE owner_id = ?', [u.id, old]);
      await txn.rawUpdate('UPDATE entries SET created_by = ? WHERE created_by = ?', [u.id, old]);
      await txn.rawUpdate('UPDATE entries SET updated_by = ? WHERE updated_by = ?', [u.id, old]);
      await txn.rawUpdate('UPDATE entry_changes SET changed_by = ? WHERE changed_by = ?', [u.id, old]);
      await txn.rawUpdate('UPDATE account_members SET user_id = ? WHERE user_id = ?', [u.id, old]);
      await _setMeta(txn, 'fresh', '1');
    });
    await settings.setCloudUser(u.id);
    if (settings.name.trim().isEmpty && name != (u.email ?? 'You')) {
      await settings.setName(name);
    }
    await ledger.reload();
    _seenRevision = ledger.revision;
  }

  // -------------------------------------------------------------- triggers

  void _onLedger() {
    if (ledger.revision == _seenRevision) return;
    _seenRevision = ledger.revision;
    // The screen refreshing with downloaded rows is not a change to upload.
    if (_showingArrivals) return;
    unawaited(_countPending());
    if (signedIn) _schedule(_uploadDelay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && signedIn) _schedule(Duration.zero);
    // Back from the Custom Tab. A session on its way arrives by itself; if
    // none comes, they closed it without signing in.
    if (state == AppLifecycleState.resumed && signingIn && _popup == null) {
      _signInBackedOut?.cancel();
      _signInBackedOut = Timer(const Duration(seconds: 5), () => _setSigningIn(false));
    }
    if (state == AppLifecycleState.paused) _signInBackedOut?.cancel();
  }

  void _schedule(Duration after) {
    _debounce?.cancel();
    _debounce = Timer(after, () => unawaited(sync()));
  }

  /// A change by another device (or person) to any row this user can see
  /// starts a download. The message itself is not used: the download
  /// fetches everything newer than the last one.
  void _listenForChanges() {
    unawaited(_channel?.unsubscribe());
    var channel = _client.channel('cash-flow-${_uid ?? ''}');
    for (final t in AppDatabase.syncedTables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        callback: (_) => _schedule(const Duration(milliseconds: 600)),
      );
    }
    _channel = channel.subscribe();
  }

  // ------------------------------------------------------------------- sync

  /// Uploads waiting changes, then downloads new ones. Safe to call any
  /// time: a call during a run makes that run go round once more.
  Future<void> sync() async {
    if (!signedIn || _deleting) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    status = SyncState.syncing;
    notifyListeners();
    try {
      var arrived = false;
      do {
        _again = false;
        arrived = await _dropStarterBooks() || arrived;
        await _push();
        arrived = await _pull() || arrived;
      } while (_again);
      if (arrived) {
        _showingArrivals = true;
        try {
          await ledger.syncArrived();
        } finally {
          _showingArrivals = false;
        }
      }
      await _remember();
      await _announce();
      await _refreshInvitations();
      status = SyncState.synced;
      lastSynced = DateTime.now();
      error = null;
    } on PostgrestException catch (e) {
      status = SyncState.failed;
      error = e.message;
    } on AuthException catch (e) {
      status = SyncState.failed;
      error = e.message;
    } catch (e) {
      // No connection, a timeout, or the server out of reach.
      status = SyncState.offline;
      error = '$e';
    } finally {
      _running = false;
      await _countPending();
      notifyListeners();
    }
  }

  /// On the first sync after signing in on a new device, the empty
  /// "Personal" account made at first launch would otherwise upload beside
  /// the books already in the cloud. If nothing was written to it and the
  /// cloud has books, it goes.
  /// Returns whether it went.
  Future<bool> _dropStarterBooks() async {
    if (await _meta(_db, 'fresh') == null) return false;
    final cloud = await _client.from('accounts').select('id').limit(1);
    final untouched = await _count('SELECT COUNT(*) FROM entries') == 0 &&
        await _count("SELECT COUNT(*) FROM account_members WHERE role != 'owner'") == 0 &&
        await _count('SELECT COUNT(*) FROM accounts') <= 1;
    final drop = cloud.isNotEmpty && untouched;
    await _db.transaction((txn) async {
      if (drop) {
        await _applying(txn, () async {
          await txn.delete('account_members');
          await txn.delete('accounts');
          await txn.delete('sync_outbox');
        });
      }
      await txn.delete('sync_meta', where: 'key = ?', whereArgs: ['fresh']);
    });
    return drop;
  }

  // ----------------------------------------------------------------- upload

  Future<void> _push() async {
    for (final table in AppDatabase.syncedTables) {
      while (true) {
        final queued = await _db.query(
          'sync_outbox',
          where: 'tbl = ?',
          whereArgs: [table],
          orderBy: 'seq',
          limit: 200,
        );
        if (queued.isEmpty) break;

        final upserts = [for (final q in queued) if (q['op'] == 'upsert') q['row_id'] as String];
        final deletes = [for (final q in queued) if (q['op'] == 'delete') q['row_id'] as String];

        if (upserts.isNotEmpty) {
          final rows = await _db.query(table, where: 'id IN (${_marks(upserts.length)})', whereArgs: upserts);
          final owned = table == 'account_members' || table == 'accounts' ? await _ownedAccounts() : const <String>{};
          final payload = [
            for (final r in rows) ?_toCloud(table, r, owned),
          ];
          await _upload(table, payload);
          if (table == 'entry_changes') await _pushToOthers([for (final r in rows) r['id'] as String]);
        }
        // Accounts and entries are only ever soft-deleted in the cloud (so
        // the deletion syncs too); a hard delete here is local only. People
        // removed from an account are really removed.
        if (deletes.isNotEmpty && table == 'account_members') {
          await _guard(() => _client.from(table).delete().inFilter('id', deletes));
        }

        final seqs = [for (final q in queued) q['seq']];
        await _db.delete('sync_outbox', where: 'seq IN (${_marks(seqs.length)})', whereArgs: seqs);
      }
    }
  }

  Future<void> _upload(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from(table).upsert(rows);
    } on PostgrestException catch (e) {
      if (!_rejectCodes.contains(e.code)) rethrow;
      // One row is refused: send them one by one so the rest still go.
      for (final r in rows) {
        await _guard(() => _client.from(table).upsert(r));
      }
    }
  }

  /// Runs [call], counting (not throwing) a refusal by the cloud.
  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } on PostgrestException catch (e) {
      if (!_rejectCodes.contains(e.code)) rethrow;
      rejected++;
      error = e.message;
      debugPrint('Cash Flow sync: refused by the cloud: ${e.message}');
    }
  }

  Future<Set<String>> _ownedAccounts() async => {
    for (final r in await _db.query('accounts', columns: ['id'], where: "role = 'owner'")) r['id'] as String,
  };

  /// A local row in the cloud's shape, or null when it is not this
  /// device's to upload.
  Map<String, Object?>? _toCloud(String table, Map<String, Object?> row, Set<String> owned) {
    final r = Map<String, Object?>.of(row);
    switch (table) {
      case 'accounts':
        if (!owned.contains(r['id'])) return null;
        r.remove('role');
        r['is_shared'] = r['is_shared'] == 1;
      case 'account_members':
        // The cloud adds each account's owner itself.
        if (r['role'] == AccountRole.owner.name || !owned.contains(r['account_id'])) return null;
        // An invite has no user until the person accepts it.
        final user = r['user_id'] as String;
        if (user.startsWith('phone:') || user.startsWith('email:')) r['user_id'] = null;
      case 'entry_changes':
        for (final k in ['old_data', 'new_data']) {
          final v = r[k];
          if (v is String) r[k] = jsonDecode(v);
        }
    }
    return r;
  }

  // --------------------------------------------------------------- download

  /// Returns whether anything arrived.
  Future<bool> _pull() async {
    var arrived = false;
    for (final table in ['accounts', 'entries', 'entry_changes']) {
      arrived = await _pullTable(table) || arrived;
    }
    var visible = await _pullMembers();
    // Accounts shared with this user since the last time (an invitation
    // accepted here or on another device, a QR code) come down whole.
    final local = {for (final r in await _db.query('accounts', columns: ['id'])) r['id'] as String};
    final missing = visible.difference(local);
    if (missing.isNotEmpty) {
      await _pullAccounts(missing);
      visible = await _pullMembers();
      arrived = true;
    }
    await _db.transaction((txn) => _applying(txn, () => _fixRoles(txn)));
    arrived = await _dropLost(visible) || arrived;
    return arrived;
  }

  /// Everything in the accounts [ids]: the accounts, their entries and
  /// their history, a page at a time.
  Future<void> _pullAccounts(Set<String> ids) async {
    final list = ids.toList();
    for (final (table, column) in [('accounts', 'id'), ('entries', 'account_id'), ('entry_changes', 'account_id')]) {
      final columns = await _columns(table);
      var after = _nilId;
      while (true) {
        final rows = await _client
            .from(table)
            .select()
            .inFilter(column, list)
            .gt('id', after)
            .order('id', ascending: true)
            .limit(_pageSize);
        if (rows.isEmpty) break;
        await _db.transaction((txn) => _applying(txn, () async {
          for (final r in rows) {
            await _write(txn, table, _toLocal(table, r, columns));
          }
        }));
        after = rows.last['id'] as String;
        if (rows.length < _pageSize) break;
      }
    }
  }

  /// Accounts shared with this user that they can no longer see (they
  /// were removed, or left) leave this device too. Returns whether any did.
  Future<bool> _dropLost(Set<String> visible) async {
    final lost = [
      for (final r in await _db.query('accounts', columns: ['id'], where: "role != 'owner'"))
        if (!visible.contains(r['id'])) r['id'] as String,
    ];
    if (lost.isEmpty) return false;
    final marks = _marks(lost.length);
    await _db.transaction((txn) => _applying(txn, () async {
      for (final t in ['entry_changes', 'entries', 'account_members']) {
        await txn.delete(t, where: 'account_id IN ($marks)', whereArgs: lost);
      }
      await txn.delete('accounts', where: 'id IN ($marks)', whereArgs: lost);
    }));
    return true;
  }

  /// Fetches rows of [table] changed since the last download, in
  /// (updated_at, id) order, a page at a time.
  Future<bool> _pullTable(String table) async {
    final key = 'cursor:$table';
    final since = await _meta(_db, key);
    // A row stamped just before the last download may have been committed
    // just after it. Looking back a little catches it; rows seen twice are
    // simply written again.
    var afterTime = since == null
        ? null
        : DateTime.parse(since).toUtc().subtract(const Duration(seconds: 5)).toIso8601String();
    var afterId = _nilId;
    final columns = await _columns(table);
    var arrived = false;

    while (true) {
      var query = _client.from(table).select();
      if (afterTime != null) {
        query = query.or('updated_at.gt."$afterTime",and(updated_at.eq."$afterTime",id.gt.$afterId)');
      }
      final rows = await query.order('updated_at', ascending: true).order('id', ascending: true).limit(_pageSize);
      if (rows.isEmpty) break;

      final waiting = await _waiting(table);
      await _db.transaction((txn) async {
        await _applying(txn, () async {
          for (final r in rows) {
            // A newer change on this device wins; it uploads next and
            // comes back down afterwards.
            if (waiting.contains(r['id'])) continue;
            // History already here is not news. It only changes when the
            // person who made it deletes their account and their name goes.
            final isNew = table == 'entry_changes' &&
                (await txn.query(table, columns: ['id'], where: 'id = ?', whereArgs: [r['id']])).isEmpty;
            if (await _write(txn, table, _toLocal(table, r, columns))) {
              arrived = true;
              // Someone else's change, after the first download: tell them.
              if (isNew && since != null && r['changed_by'] != _uid) _news.add(r);
            }
          }
        });
        final last = rows.last;
        afterTime = _utc(last['updated_at'] as String);
        afterId = last['id'] as String;
        await _setMeta(txn, key, afterTime!);
      });
      if (rows.length < _pageSize) break;
    }
    return arrived;
  }

  /// Members are few, so all of them come down each time; that way people
  /// removed from an account disappear here too. Returns the accounts this
  /// user can see.
  Future<Set<String>> _pullMembers() async {
    final rows = await _client.from('account_members').select();
    final columns = await _columns('account_members');
    final waiting = await _waiting('account_members');
    final ids = {for (final r in rows) r['id'] as String};
    final accounts = {for (final r in rows) r['account_id'] as String};

    await _db.transaction((txn) async {
      await _applying(txn, () async {
        final known = {for (final r in await txn.query('accounts', columns: ['id'])) r['id'] as String};
        for (final r in rows) {
          if (waiting.contains(r['id']) || !known.contains(r['account_id'])) continue;
          final row = _toLocal('account_members', r, columns);
          // The cloud's copy of a person replaces the one made here.
          await txn.delete(
            'account_members',
            where: 'account_id = ? AND user_id = ? AND id != ?',
            whereArgs: [row['account_id'], row['user_id'], row['id']],
          );
          await _write(txn, 'account_members', row);
        }
        for (final local in await txn.query('account_members', columns: ['id', 'account_id'])) {
          final id = local['id'] as String;
          if (accounts.contains(local['account_id']) && !ids.contains(id) && !waiting.contains(id)) {
            await txn.delete('account_members', where: 'id = ?', whereArgs: [id]);
          }
        }
      });
    });
    return accounts;
  }

  /// Each account's role here is this user's role in it.
  Future<void> _fixRoles(Transaction txn) => txn.rawUpdate(
    '''UPDATE accounts SET role = COALESCE(
         (SELECT m.role FROM account_members m
          WHERE m.account_id = accounts.id AND m.user_id = ? AND m.status = 'active'),
         CASE WHEN owner_id = ? THEN 'owner' ELSE 'viewer' END)''',
    [_uid, _uid],
  );

  /// A cloud row in the device's shape: only the columns kept here, and
  /// timestamps in the same text form as the rest.
  Map<String, Object?> _toLocal(String table, Map<String, dynamic> row, Set<String> columns) {
    final r = <String, Object?>{};
    for (final MapEntry(:key, :value) in row.entries) {
      if (!columns.contains(key) || key == 'role' && table == 'accounts') continue;
      r[key] = switch (value) {
        bool b => b ? 1 : 0,
        Map<String, dynamic> m => jsonEncode(m),
        String s when key.endsWith('_at') => toIso(DateTime.parse(s)),
        _ => value,
      };
    }
    if (table == 'account_members' && r['user_id'] == null) {
      final phone = r['phone'] as String? ?? '';
      r['user_id'] = phone.isNotEmpty ? 'phone:$phone' : 'email:${(r['email'] as String? ?? '').toLowerCase()}';
    }
    return r;
  }

  /// Updates the row, or inserts it when new. Not INSERT OR REPLACE: that
  /// deletes first, and deleting an account cascades to its entries.
  ///
  /// Returns whether anything changed. Each download looks back a little
  /// and sees the newest rows again; those are left alone and do not count
  /// as news, or every download would refresh the screen and start another.
  Future<bool> _write(Transaction txn, String table, Map<String, Object?> row) async {
    final existing = await txn.query(table, where: 'id = ?', whereArgs: [row['id']]);
    if (existing.isEmpty) {
      await txn.insert(table, row);
      return true;
    }
    final old = existing.first;
    if (row.entries.every((e) => old[e.key] == e.value)) return false;
    await txn.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    return true;
  }

  // ----------------------------------------------------------- sharing

  Future<void> _refreshInvitations() async {
    final rows = await _client.rpc('my_invitations') as List;
    final list = [for (final r in rows) Invitation._(r as Map<String, dynamic>)];
    if (list.length != invitations.length ||
        list.indexed.any((e) => e.$2.memberId != invitations[e.$1].memberId)) {
      invitations = list;
      notifyListeners();
    }
  }

  /// Joins the account [i] is for. Its entries and history come down
  /// straight away. Returns the account's id.
  Future<String> acceptInvitation(Invitation i) async {
    final id = await _client.rpc('accept_invitation', params: {'p_member': i.memberId}) as String;
    invitations = [for (final x in invitations) if (x.memberId != i.memberId) x];
    notifyListeners();
    await sync();
    return id;
  }

  Future<void> declineInvitation(Invitation i) async {
    await _client.rpc('decline_invitation', params: {'p_member': i.memberId});
    invitations = [for (final x in invitations) if (x.memberId != i.memberId) x];
    notifyListeners();
  }

  /// A QR code (and link) that lets whoever scans it join [accountId] as
  /// [role], for a day. Needs the internet; the account uploads first.
  Future<InviteCode> createInviteCode(String accountId, AccountRole role) async {
    await sync();
    final row = await _client
        .from('account_invites')
        .insert({'account_id': accountId, 'role': role.name})
        .select('id, expires_at')
        .single();
    return InviteCode(row['id'] as String, DateTime.parse(row['expires_at'] as String).toLocal());
  }

  /// Stops a code early, so nobody else can join with it.
  Future<void> stopInviteCode(String code) => _client
      .from('account_invites')
      .update({'stopped_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', code);

  /// What a scanned code is for, or null if there is no such code.
  Future<CodeDetails?> codeDetails(String code) async {
    final rows = await _client.rpc('invite_code_details', params: {'p_code': code}) as List;
    return rows.isEmpty ? null : CodeDetails._(rows.first as Map<String, dynamic>);
  }

  /// Joins the account a code is for. Returns the account's id.
  Future<String> joinWithCode(String code) async {
    final id = await _client.rpc('join_with_code', params: {'p_code': code}) as String;
    await sync();
    return id;
  }

  /// For the bell: how many changes by others are unread, plus
  /// invitations waiting for an answer.
  int get unread => settings.unreadChanges.length + invitations.length;

  bool isUnread(String changeId) => settings.unreadChanges.contains(changeId);

  Future<void> markRead(String changeId) async {
    final ids = settings.unreadChanges;
    if (!ids.remove(changeId)) return;
    await settings.setUnreadChanges(ids);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await settings.setUnreadChanges({});
    notifyListeners();
  }

  /// The changes just downloaded stay unread in the bell until opened.
  Future<void> _remember() async {
    if (_news.isEmpty) return;
    await settings.setUnreadChanges({...settings.unreadChanges, for (final n in _news) n['id'] as String});
  }

  /// Asks the server to push the changes just uploaded to the other people
  /// in their accounts. Only changes in accounts shared with someone who
  /// has accepted go. A failure only costs the push: the change is in.
  Future<void> _pushToOthers(List<String> changeIds) async {
    if (changeIds.isEmpty) return;
    final shared = await _db.rawQuery(
      '''SELECT c.id FROM entry_changes c
         WHERE c.id IN (${_marks(changeIds.length)})
           AND EXISTS (SELECT 1 FROM account_members m
                       WHERE m.account_id = c.account_id AND m.role != 'owner' AND m.status = 'active')''',
      changeIds,
    );
    if (shared.isEmpty) return;
    try {
      await _client.functions.invoke('notify-changes', body: {
        'change_ids': [for (final r in shared) r['id']],
      });
    } catch (e) {
      debugPrint('Cash Flow: could not ask for pushes: $e');
    }
  }

  /// Changes other people made, as notifications: one per change, or one
  /// per account when several came at once. On a phone with Firebase,
  /// the server's push already said it.
  Future<void> _announce() async {
    if (_news.isEmpty) return;
    final news = [..._news];
    _news.clear();
    if (!settings.notifyChanges || _pushes.active) return;
    final names = {for (final a in ledger.accounts) a.id: a.name};
    final byAccount = <String, List<Map<String, dynamic>>>{};
    for (final n in news) {
      (byAccount[n['account_id'] as String] ??= []).add(n);
    }
    String who(Map<String, dynamic> n) {
      final name = (n['changed_by_name'] as String? ?? '').trim();
      return name.isEmpty ? 'Someone' : name;
    }

    for (final MapEntry(key: id, value: list) in byAccount.entries) {
      final account = names[id] ?? 'A shared account';
      if (list.length == 1) {
        final n = list.single;
        final data = (n['new_data'] ?? n['old_data']) as Map<String, dynamic>? ?? const {};
        final did = switch (n['action']) {
          'created' => 'added',
          'updated' => 'edited',
          _ => 'deleted',
        };
        final kind = data['type'] == 'in' ? 'Cash In' : 'Cash Out';
        final note = (data['note'] as String? ?? '').trim();
        final amount = data['amount'] is num ? ' ${Fmt.money(data['amount'] as num)}' : '';
        await Notifier.show(account, '${who(n)} $did $kind$amount${note.isEmpty ? '' : ': $note'}');
      } else {
        final people = {for (final n in list) who(n)}.join(', ');
        await Notifier.show(account, '$people made ${list.length} changes');
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  /// Runs [work] with the outbox triggers off, for rows from the cloud.
  static Future<void> _applying(Transaction txn, Future<void> Function() work) async {
    await _setMeta(txn, 'applying', '1');
    await work();
    await txn.delete('sync_meta', where: 'key = ?', whereArgs: ['applying']);
  }

  Future<void> _wipeLocal() async {
    await _db.transaction((txn) async {
      await _applying(txn, () async {
        for (final t in AppDatabase.syncedTables.reversed) {
          await txn.delete(t);
        }
      });
      await txn.delete('sync_outbox');
      await txn.delete('sync_meta');
    });
  }

  Future<void> _countPending() async {
    final n = await _count('SELECT COUNT(*) FROM sync_outbox');
    if (n != pending) {
      pending = n;
      notifyListeners();
    }
  }

  Future<int> _count(String sql) async {
    final rows = await _db.rawQuery(sql);
    return (rows.first.values.first as num? ?? 0).toInt();
  }

  Future<Set<String>> _waiting(String table) async => {
    for (final r in await _db.query('sync_outbox', columns: ['row_id'], where: 'tbl = ?', whereArgs: [table]))
      r['row_id'] as String,
  };

  final _columnCache = <String, Set<String>>{};
  Future<Set<String>> _columns(String table) async => _columnCache[table] ??= {
    for (final r in await _db.rawQuery('PRAGMA table_info($table)')) r['name'] as String,
  };

  static Future<String?> _meta(DatabaseExecutor ex, String key) async {
    final rows = await ex.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> _setMeta(DatabaseExecutor ex, String key, String value) =>
      ex.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  /// The server's timestamp as UTC text, keeping its microseconds (a
  /// DateTime on the web would drop them, and the next page would repeat).
  static String _utc(String s) => s.endsWith('+00:00') ? '${s.substring(0, s.length - 6)}Z' : toIso(DateTime.parse(s));

  static String _marks(int n) => List.filled(n, '?').join(', ');
}

/// Someone shared an account with this user; they have not answered yet.
class Invitation {
  final String memberId;
  final String accountId;
  final String accountName;
  final AccountRole role;
  final String invitedBy;
  final DateTime invitedAt;

  Invitation._(Map<String, dynamic> r)
    : memberId = r['member_id'] as String,
      accountId = r['account_id'] as String,
      accountName = r['account_name'] as String? ?? '',
      role = AccountRole.parse(r['role'] as String?),
      invitedBy = r['invited_by_name'] as String? ?? '',
      invitedAt = DateTime.parse(r['invited_at'] as String).toLocal();
}

/// A QR code an owner made for an account.
class InviteCode {
  final String code;
  final DateTime expiresAt;
  const InviteCode(this.code, this.expiresAt);
}

/// What a scanned code is for.
class CodeDetails {
  final String accountId;
  final String accountName;
  final AccountRole role;
  final String invitedBy;
  final bool usable;
  final bool alreadyMember;

  CodeDetails._(Map<String, dynamic> r)
    : accountId = r['account_id'] as String,
      accountName = r['account_name'] as String? ?? '',
      role = AccountRole.parse(r['role'] as String?),
      invitedBy = r['invited_by_name'] as String? ?? '',
      usable = r['usable'] as bool? ?? false,
      alreadyMember = r['already_member'] as bool? ?? false;
}
